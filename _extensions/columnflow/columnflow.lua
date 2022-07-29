columnFilterWord = {
  Div = function(el)
    
    if el.classes:includes("columns") then
      -- do the thing

      -- okay, section properties are kind of insane in word/odt:
      -- the sectPr element that column defs go in EITHER goes inside the last
      -- par of the section (for all sections but the last) or as the last child
      -- of the body element (for the last section).

      -- that's going to make converting a div to a section a pain in the butt!
      -- we'll have to traverse the doc to find existing sections
      -- http://officeopenxml.com/WPsection.php

      -- docx writer:
      -- https://github.com/jgm/pandoc/blob/master/src/Text/Pandoc/Writers/Docx.hs

      -- 1) write the style element wit hthe column spec
      column_spec_inline = pandoc.RawInline("openxml", [[
        <w:sectPr>
          <w:cols w:num="2" w:sep="1" w:space="720" w:equalWidth="0">
            <w:col w:w="5760" w:space="720"/>
            <w:col w:w="2880"/>
          </w:cols>
        </w:sectPr>]])

      -- 2) locate the last para in this div
      last_par = el.content[#el.content]

      -- last_par.insert(#last_par, pandoc.Str("HELLO"))

      quarto.utils.dump(">>> Last par reference")
      quarto.utils.dump(last_par)

      -- quarto.utils.dump(">>> Last par content")
      -- quarto.utils.dump(last_par.content)
      table.insert(
        last_par.content,
        -- #last_par.content + 1,
        1,
        -- pandoc.Str("HELLO")
        column_spec_inline
      )

      quarto.utils.dump(">>> Last par in original context:")
      quarto.utils.dump(el.content[#el.content])

      -- 3) insert it

      -- https://pandoc.org/lua-filters.html#pandoc.list:insert
      -- pandoc.List:insert ([pos], value)

      -- 4) (let's forget baout the surrounding context for now;
      --    hopefully the docx writer will sort it)

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
