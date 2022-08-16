-- james goldie, july 2022

--helper adapted from https://www.lua.org/pil/13.1.html
function intersection(a, b)
  local res = {}
  for k in pairs(a) do
    res[k] = b[k]
  end
  return res
end

wordFilters = {

  --  wordBlocks adds a single-column spec to the very end of the doc (this is
  --    required by Word's section rules)
  Blocks = function(all_blocks)

    print(">>> Blocks invocation count: " .. tostring(blocks_runcount))
    
    -- abort if this filter has already run
    if blocks_runcount > 0 then
      return all_blocks
    end
    blocks_runcount = blocks_runcount + 1;
    quarto.utils.dump("> RUNNING WORDBLOCKS")

    quarto.utils.dump(">>> Adding single-col at the end, after:")
    quarto.utils.dump(all_blocks[#all_blocks])

    -- table.insert(el.content[#el.content].content, 1, column_spec_inline)
    
    -- just insert a single col spec inline to the last par of the doc
    table.insert(all_blocks[#all_blocks].content, 1,
      pandoc.RawBlock(
        "openxml",
        [[<w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr>]]))

    return all_blocks

  end,

  -- wordDiv marked .columnflow sections, adding the user's specified
  --   columns to the last par and a single-column section marker to the start
  Div = function(el)
    
    
    if el.classes:includes("columnflow") then
      quarto.utils.dump("> RUNNING WORDDIV")
    
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
        [[<w:pPr><w:sectPr><w:type w:val="continuous" />]] ..
        col_spec_middle ..
        [[</w:cols></w:sectPr></w:pPr>]])

      -- we also need a single-column style definition at the start of our
      -- section, so that the columns don't run all the way back to the start
      -- of the document
      prev_section_colspec_inline = pandoc.RawInline("openxml",
        [[<w:pPr><w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr></w:pPr>]])

      -- add an empty par at the start of the section for the 1-column spec,
      -- and a multi-col spec the last par
      -- quarto.utils.dump(">>> Adding single-col before:")
      -- quarto.utils.dump(el.content[1])
      table.insert(el.content, 1, pandoc.Para(prev_section_colspec_inline))
      -- quarto.utils.dump(">>> Adding multi-col in:")
      -- quarto.utils.dump(el.content[#el.content])
      table.insert(el.content[#el.content].content, 1, column_spec_inline)

      -- now add the multi-column spec: either to the last par if there're
      -- multiple, or to an empty par at the end if there's just one
      -- if #el.content > 1 then
      --   -- if there're multiple pars, insert the column specs into them inline
      -- else
      --   -- if there's just one par, add dummy pars first
      --   table.insert(el.content, #el.content + 1,
      --     pandoc.Para(column_spec_inline))
      -- end      

      return el
    end
  end

}

-- odtDiv (WIP)
odtDiv = function(el)
  
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


if FORMAT == "docx" then
  -- docx: run wordBlocks *once* on full doc; run wordDiv on ea. .columnflow div
  quarto.utils.dump("> RUNNING WORD")
  blocks_runcount = 0
  traverse = "topdown"
  return { wordFilters }
-- else if FORMAT == "odt" then
--   return {Div = odtDiv}
else
  return
end
