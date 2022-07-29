columnFilterWord = {
  Blocks = function(all_blocks)
    quarto.utils.dump(">>> PROCESSING BLOCK LIST")
    quarto.utils.dump(all_blocks)

    -- this runs once for the columns section, then again for
    -- the "top" section (all the pars)

    -- in the latter run, that section appears as a div (so we have a list of blocks - some are paras, some are divs)

    -- so here's what we do:
    -- 1) identify the div.columns in all_blocks (what're their positions?)
    -- 2) insert the column spec into the last par of each div.columns
    -- 3) insert the 1-col spec into the last par of each previous block
    -- 4) insert the 1-col spec into the last par, if this is the body and not
    --    a section (AND if the section isn't the last par!)

    -- ... how do i check the type of this list?

  end,

  Div = function(el)
    
    if el.classes:includes("columns") then
      -- do the thing
      quarto.utils.dump(">>> PROCESSING COLUMNS SECTION")

      -- 1) write the style element with the column spec
      column_spec_inline = pandoc.RawInline("openxml", [[
        <w:sectPr>
          <w:cols w:num="2" w:sep="1" w:space="720" w:equalWidth="0">
            <w:col w:w="5760" w:space="720"/>
            <w:col w:w="2880"/>
          </w:cols>
        </w:sectPr>]])

      -- 2) locate the last para in this div
      last_par = el.content[#el.content]

      quarto.utils.dump(">>> Last par reference")
      quarto.utils.dump(last_par)
      
      quarto.utils.dump(">>> Last par in original context:")
      quarto.utils.dump(el.content[#el.content])
      
      -- 3) insert it
      -- table.insert(
      --   last_par.content,
      --   1,
      --   column_spec_inline)

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
if quarto.doc.isFormat("odt") then
  return {columnFilterODT}
elseif quarto.doc.isFormat("docx") then
  return {columnFilterWord}
-- else if quarto.doc.isFormat("pdf") then
--   return {columnFilterPDF}
else
  return
end
