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
  return {columnFilter}
else
  return
end
