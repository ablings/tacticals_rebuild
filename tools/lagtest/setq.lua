local e = Enum.QualityLevel["Level" .. string.format("%02d", tonumber("{{Q}}"))]
pcall(function() settings().Rendering.EditQualityLevel = e end)
pcall(function() settings().Rendering.QualityLevel = e end)
return tostring(settings().Rendering.QualityLevel)
