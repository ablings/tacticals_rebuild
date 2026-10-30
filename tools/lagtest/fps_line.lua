-- Client: compact render numbers for the FPS table
local S = game:GetService("Stats"); local F = S.FrameRateManager
local function g(k) local it = F:FindFirstChild(k); local ok, v = pcall(function() return it:GetValue() end); return ok and v or -1 end
local tris, draws = 0, 0
for _, c in S.RenderBreakdown:GetChildren() do local t, d = c:GetValueString():match("(%d+) tris, (%d+) draws"); tris += tonumber(t) or 0; draws += tonumber(d) or 0 end
return string.format("fb %dx%d | view %dk tris %d draws | all ~%dk tris %d batches | gpu %.1fms render-thread %.1fms | mem tex %.0f MB",
  g("FramebufferWidth"), g("FramebufferHeight"), tris / 1000, draws, g("Indices") / 3000, g("Batches"), g("AverageGPU"), g("RenderThreadAverage"),
  S:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture))
