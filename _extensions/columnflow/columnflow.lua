-- james goldie, july 2022

--helper adapted from https://www.lua.org/pil/13.1.html
function intersection(a, b)
  local res = {}
  for k in pairs(a) do
    res[k] = b[k]
  end
  return res
end

-- the word filter has two elements:
--  - Div processes marked .columnflow sections, adding the user's specified
--    columns to the last par and a single-column section marker to the start
--  - Blocks adds a single-column spec to the very end of the doc (this is
--    required by Word's section rules)
columnFilterWord = {
  Blocks = function(all_blocks)

    -- abort if this blocklist isn't the main article body
    -- TODO - tighten this up! we need to be 100% sure this is the main article
    -- body and not some other subsection
    if string.find(tostring(all_blocks[#all_blocks]), "<w:cols") then
      return all_blocks
    end
    
    -- just insert a single col spec right at the end
    table.insert(all_blocks, #all_blocks + 1,
      pandoc.RawBlock(
        "openxml",
        [[<w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr>]]))

    return all_blocks

  end,

  Div = function(el)
    
    if el.classes:includes("columnflow") then
    
      -- 1) get the relevant attributes from the block attributes:
      --    - count: number of equal-width columns
      --    - widths: width of each column, separated by spaces
      --    - space: spacing after each column. if one is provided, it's used
      --        for each column except the last
      --    - sep: if provided, draw a line bwteen each column

      -- draw a border if col-sep is present (and not "0")
      col_sep = 
        (el.attributes["col-sep"] ~= nil and
          el.attributes["col-sep"] ~= "0") and
        "1" or
        "0"
      -- gap between columns: default to 0.5 inches
      col_space_arg =
        (el.attributes["col-space"] ~= nil) and
        el.attributes["col-space"] or
        "0.5"


      -- 2) construct the middle of the column spec (where we actually define
      -- the number, width and spacing of columns)

      -- get the column width/color
      if el.attributes["col-widths"] ~= nil then
        -- unequal widths: split the widths up and map to column spec
        
        -- extract the widths
        col_widths = {}
        for i in string.gmatch(el.attributes["col-widths"], "%S*") do
          table.insert(col_widths, i)
        end

        -- extract the space after each column
        col_spaces = {}
        
        for i in string.gmatch(col_space_arg, "%S*") do
          table.insert(col_spaces, i)
        end

        -- check to make sure we have enough seps to match the widths.
        -- if one is specified, recycle it over all columns but the last
        if (#col_spaces == 1) then
          while #col_spaces < #col_widths do
            table.insert(col_spaces, col_spaces[1])
          end
          -- make the last col spacing 0 if we're relying on recycling
          col_spaces[#col_spaces] = "0"
        end

        assert(#col_widths == #col_spaces, [[
          Error: when you specify columns of unequal widths, either:
            (a) specify the spacing after each column,
            (b) specify one spacing, to be used for all columns but the
              last,
            (c) do not specify any spacing (default will be 0.5 inches
                for all columns but the last) ]])

        -- begin the column spec with <w:cols>
        col_spec_middle =
          [[<w:cols w:num="]] .. #col_widths .. [[" w:sep="]] .. col_sep ..
          [[" w:equalWidth="0">\n]]

        -- add the <w:col> child elements, converting widths and spacing
        -- from inches to 1440ths of an inch as we go
        for i = 1,#col_widths do
          col_spec_middle = col_spec_middle ..
            [[<w:col w:w="]] .. col_widths[i] * 1440 ..
            [[" w:space="]] .. col_spaces[i] * 1440 .. [["/>\n]]
        end
        
      else
        -- equal widths (default 2)

        if el.attributes["col-count"] ~= nil then
          col_count = el.attributes["col-count"]
        else
          col_count = 2
        end

        -- gap between columns: default to 0.5 inches
        col_spaces =
          (el.attributes["col-spaces"] ~= nil) and
          el.attributes["col-spaces"] or
          "0.5"

        col_spec_middle = 
          [[<w:cols w:num="]] .. col_count .. [[" w:sep="]] .. col_sep ..
          [[" w:space="]] .. col_spaces * 1440 .. [[" w:equalWidth="1">]]
        
      end

      -- construct the rest of the column spec
      column_spec_inline = pandoc.RawInline("openxml",
        [[<w:pPr><w:sectPr><w:type w:val="continuous" />\n]] ..
        col_spec_middle ..
        [[</w:cols></w:sectPr></w:pPr>]])

      -- we also need a single-column style definition at the start of our
      -- section, so that the columns don't run all the way back to the start
      -- of the document
      prev_section_colspec_inline = pandoc.RawInline("openxml",
        [[<w:pPr><w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr></w:pPr>]])

      if #el.content > 1 then
        -- if there're multiple pars, insert the column specs into them inline
        table.insert(el.content[1].content, 1, prev_section_colspec_inline)
        table.insert(el.content[#el.content].content, 1, column_spec_inline)
      else
        -- if there's just one par, add dummy pars first
        table.insert(el.content, 1, pandoc.Para(prev_section_colspec_inline))
        table.insert(el.content, #el.content + 1,
          pandoc.Para(column_spec_inline))
      end      

      return el
    end
  end
}

columnFilterODT = {
  Div = function(el)
    
    if el.classes:includes("columns") then
      -- do the thing
      
      -- it looks much easier in odt format:
      -- the section gets a parent element, text:section, with properties:
      --   text:style-name="Sect1" text:name="TextSection"
      -- then, in office:automatic-styles, you define a style:style with:
      --   style:name="Sect1" style:family="section"
      -- it then gets, for example:
      -- <style:style style:name="Sect1" style:family="section">
      --   <style:section-properties text:dont-balance-text-columns="true" style:editable="false">
      --     <style:columns fo:column-count="2">
      --       <style:column style:rel-width="32769*" fo:start-indent="0in" fo:end-indent="0.25in" />
      --       <style:column style:rel-width="32766*" fo:start-indent="0.25in" fo:end-indent="0in" />
      --     </style:columns>
      --   </style:section-properties>
      -- </style:style>

      -- odt writer:
      -- https://github.com/jgm/pandoc/blob/master/src/Text/Pandoc/Writers/ODT.hs

      -- create the text:section that will hold our columned content
      pandoc.RawBlock("opendocument",
        [[<text:section text:style-name="Sect1" text:name="TextSection">]])

      -- create a style:style that will go in office:automatic-styles
  
    end
  end
}

-- return the filter if the format matches
if FORMAT == "docx" then
  return {columnFilterWord}
else
  return
end
