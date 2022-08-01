-- james goldie, july 2022

-- adapted from https://www.lua.org/pil/13.1.html
function intersection(a, b)
  local res = {}
  for k in pairs(a) do
    res[k] = b[k]
  end
  return res
end

columnFilterWord = {
  Blocks = function(all_blocks)

    -- abort if this blocklist isn't the main article body
    -- TODO - tighten this up! we need to be 100% sure this is the main article
    -- body and not some other subsection
    if string.find(tostring(all_blocks[#all_blocks].content[1]), "<w:cols") then
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
      --    - widths: width of each column, separated by commas (+ opt. spaces)
      --    - space: spacing after each column. if one is provided, it's used
      --        for each column except the last
      --    - sep: if provided, draw a line bwteen each column

      -- draw a border if col-sep is present
      col_sep = (el.attributes["col-sep"] ~= nil) and "1" or "0"
      -- gap between columns: default to 720 (1440ths of an inch?)
      col_space =
        (el.attributes["col-spaces"] ~= nil) and
        el.attributes["col-spaces"] or
        "720"

      -- 2) construct the middle of the column spec (where we actually define
      -- the number, width and spacing of columns)

      -- get the column width/color
      if el.attributes["col-widths"] ~= nil then
        -- unequal widths: split the widths up and map to column spec
        quarto.utils.dump(">>>>>> Unequal width columns:")
        
        -- extract the widths
        col_widths = {}

        for i in string.gmatch(col_widths, ",%S+") do
          table.insert(col_widths, i)
        end
        quarto.utils.dump(col_widths)

        -- extract the space after each column
        col_space = {}
        for i in string.gmatch(col_space, ",%S+") do
          table.insert(col_space, i)
        end
        quarto.utils.dump(">>>>>> Spaces:")
        quarto.utils.dump(col_space)

        -- check to make sure we have enough seps to match the widths.
        -- if one is specified, recycle it over all columns but the last
        -- if none are specified, recycle a default of 720 (0.5 inches)
        if (#col_space == 0) then
          table.insert(col_space, "720")
        end
        if (#col_space == 1) then
          while #col_space < n_col_widths do
            table.insert(col_space, col_space[1])
          end
          -- make the last col spacing 0 if we're relying on recycling
          col_space[#col_space] = "0"
        end
        assert(#col_widths ~= #col_space, [[
          Error: when you specify columns of unequal widths, either:
            (a) specify the spacing after each column,
            (b) specify one spacing, to be used for all columns but the
              last,
            (c) do not specify any spacing (default will be 720
                for all columns but the last) ]])

        -- begin the column spec with <w:cols>
        col_spec_middle =
          '<w:cols w:num="' .. #col_widths .. '" w:sep="' .. col_sep .. '" w:equalWidth="0">\n'

        -- add the <w:col> child elements, converting widths and spacing
        -- from inches to 1440ths of an inch as we go
        for i = 1,#col_widths do
          col_spec_middle = col_spec_middle ..
            '<w:col w:w="' .. col_widths[i] * 1440 ..
            '" w:space="' .. col_space[i] * 1440.. '"/>\n'
        end
        
      else
        -- equal widths (default 2)

        if el.attributes["col-count"] ~= nil then
          col_count = el.attributes["col-count"]
        else
          col_count = 2
        end

        quarto.utils.dump(">>>>>> Equal widths: " .. col_count .. " columns")

        col_spec_middle = 
          '<w:cols w:num="' .. col_count .. '" w:sep="' .. col_sep ..
          '" w:space="' .. col_space * 1440 .. '" w:equalWidth="1">'
        
      end

      -- construct the rest of the column spec
      column_spec_inline =
        '<w:pPr><w:sectPr><w:type w:val="continuous" />\n' ..
        col_spec_middle ..
        '</w:cols></w:sectPr></w:pPr>'

      -- we also need a single-column style definition at the start of our
      -- section, so that the columns don't run all the way back to the start
      -- of the document
      prev_section_colspec_inline = pandoc.RawInline("openxml",
        [[<w:pPr><w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr></w:pPr>]])

      if #el.content > 1 then
        -- if there're multiple pars, insert the column specs into them inline
        quarto.utils.dump(">>> MULTI PAR SECTION")
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
        '<text:section text:style-name="Sect1" text:name="TextSection">')

      -- create a style:style that will go in office:automatic-styles
  
      quarto.utils.dump(el.content)
  
    end
  end
}

-- return the filter if the format matches
-- NOTE - could use the pandoc global FORMAT here instead!
if quarto.doc.isFormat("docx") then
  return {columnFilterWord}
-- elseif quarto.doc.isFormat("odt") then
--   return {columnFilterODT}
-- else if quarto.doc.isFormat("pdf") then
--   return {columnFilterPDF}
else
  return
end
