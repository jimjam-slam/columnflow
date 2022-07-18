columnFilter = {
  Div = function(el)
    
    if el.classes:includes("columns") then
      -- do the thing
  
      quarto.utils.dump(el)
  
    end
  end
}


-- return the filter if the format matches
if quarto.doc.isFormat("docx") then
  return {columnFilterWord}
-- else if quarto.doc.isFormat("oft") then
--   return {columnFilterODT}
-- else if quarto.doc.isFormat("pdf") then
--   return {columnFilterPDF}
else
  return
end
