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
    quarto.utils.dump(">>> PROCESSING BLOCK LIST")
    -- quarto.utils.dump(all_blocks)

    -- this runs once for the columns section, then again for
    -- the "top" section (all the pars)

    -- in the latter run, that section appears as a div (so we have a list of blocks - some are paras, some are divs)

    -- so here's what we do:
    -- 0) check the last par in the list. is it a par that strats with a rawinline? if so, bail out. else,
    last_block = all_blocks[#all_blocks]
    quarto.utils.dump(">>>>>> LAST BLOCK ATTRIBUTES ARE...")
    quarto.utils.dump(last_block.listAttributes)
    quarto.utils.dump(">>>>>> LAST BLOCK'S FIRST CONTENT IS...")
    quarto.utils.dump(last_block.content[1])

    -- skip this invocation of the filter if the last block starts with a
    -- column spec
    if string.find(tostring(last_block.content[1]), "<w:cols") then
      return all_blocks
    end

    -- else, start by working out which blocks are div.columns and which aren't
    -- quarto.utils.dump(">>> CHECKING EACH BLOCK")
    -- col_divs = {}
    -- before_col_divs = {}
    -- other_blocks = {}
    -- for i, v in ipairs(all_blocks) do
    --   if string.find(tostring(v), "^Div") and v.classes:includes("columns") then
    --     table.insert(col_divs, i)
    --     if (i > 0) then
    --       table.insert(before_col_divs, i - 1)
    --     end
    --   else
    --     table.insert(other_blocks, i)
    --   end
    -- end

    
    -- now, which other_blocks are right before div.columns? they need 1-col
    -- specs
    -- ie. intersection other other_blocks and before_col_divs
    -- single_col_targets = intersection(other_blocks, before_col_divs)

    -- quarto.utils.dump(">>> BLOCKS THAT ARE DIV.COLUMNS")
    -- quarto.utils.dump(col_divs)
    -- quarto.utils.dump(">>> BLOCKS WHERE WE TARGET 1-COL SPECS:")
    -- quarto.utils.dump(single_col_targets)
    

    -- 3) insert the 1-col spec into the last par of each previous block
    -- NOTE - i might have this a bit wrong. this creates:
    -- <w:p>
    --   <w:pPr>
    --     <w:pStyle w:val="BodyText" />
    --   </w:pPr>
    --   <w:sectPr>
    --     <w:cols w:num="1"></w:cols>
    --   </w:sectPr>
    --   <w:r> ... paragraph content goes here

    -- should <w:sectPr> be inside <w:pPR>? Compare to a real word doc!

    -- single_column_spec_inline = pandoc.RawInline("openxml",
    --   [[<w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr>]])
      
      -- for i, n in pairs(single_col_targets) do
      --   quarto.utils.dump(">>>>>> INSERTING SINGLE-COL SPEC INTO BLOCK " .. n)
      --   table.insert(all_blocks[n].content, 1, single_column_spec_inline)
      -- end
      
    -- just insert a single col spec right at the end
    table.insert(all_blocks, #all_blocks + 1,
      pandoc.RawBlock(
        "openxml",
        [[<w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr>]]))


    -- 4) insert the 1-col spec into the last par, if this is the body and not
    --    a section (AND if the section isn't the last par!)
    -- TODO - do we need to do anything with the end of the doc?
    return all_blocks

  end,

  Div = function(el)
    
    if el.classes:includes("columns") then
      -- do the thing
      quarto.utils.dump(">>> PROCESSING DIV.COLUMNS")

      -- word generally puts the style info in the last par of the section, and
      -- it's supposed to put the previous section's info i nthe last par of
      -- _that_ section. but often it cheats and creates extra, empty pars w/
      -- no content in them, just to store the section info (esp if it's a
      -- single par section!). so maybe i should just be lazy and do it that
      -- way. no doc scanning required?

      -- 1) write the style element with the column spec
      -- TODO - is w:space in cols or col?
      -- this should all be in w:pPr!
      -- start of column section content seems to just be 
      column_spec_inline = pandoc.RawInline("openxml", [[
        <w:pPr>
          <w:sectPr>
            <w:type w:val="continuous" />
            <w:cols w:num="2" w:sep="1" w:space="720" w:equalWidth="0">
              <w:col w:w="5760" w:space="720"/>
              <w:col w:w="2880"/>
            </w:cols>
          </w:sectPr>
        </w:pPr>]])

      -- should have w:space?
      single_column_spec_inline = pandoc.RawInline("openxml",
        [[<w:pPr><w:sectPr><w:type w:val="continuous" /><w:cols /></w:sectPr></w:pPr>]])

      if #el.content > 1 then
        -- if there're multiple pars, insert the column specs into them inline
        quarto.utils.dump(">>> MULTI PAR SECTION")
        table.insert(el.content[1].content, 1, single_column_spec_inline)
        table.insert(el.content[#el.content].content, 1, column_spec_inline)
      else
        -- quarto.utils.dump(">>> SINGLE PAR SECTION")
        -- if not, create the dummy pars first
        table.insert(el.content, 1, pandoc.Para(single_column_spec_inline))
        table.insert(el.content, #el.content + 1,
          pandoc.Para(column_spec_inline))
      end      

      -- 4) now we need to insert a section break _before_ this
      --    content (so that the column start in the right place)
      --    can we be cheeky and just insert it at the start of
      --    this content? no, they'll start one par late :/

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
if quarto.doc.isFormat("odt") then
  return {columnFilterODT}
elseif quarto.doc.isFormat("docx") then
  return {columnFilterWord}
-- else if quarto.doc.isFormat("pdf") then
--   return {columnFilterPDF}
else
  return
end
