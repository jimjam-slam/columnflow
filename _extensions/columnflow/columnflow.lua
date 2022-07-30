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
      -- do the thing
      quarto.utils.dump(">>> PROCESSING DIV.COLUMNS. ATTRIBUTES ARE:")
      quarto.utils.dump(last_block.listAttributes)

      -- word generally puts the style info in the last par of the section, and
      -- it's supposed to put the previous section's info i nthe last par of
      -- _that_ section. but often it cheats and creates extra, empty pars w/
      -- no content in them, just to store the section info (esp if it's a
      -- single par section!). so maybe i should just be lazy and do it that
      -- way. no doc scanning required?

      -- 1) write the style element with the column spec
      -- TODO - column count, widths, gaps etc shouldn't be hardcoded!
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
