// Prints UsdRenderComputeSpec for the stage's render settings (oracle).
#include <pxr/usd/usd/stage.h>
#include <pxr/usd/usd/primRange.h>
#include <pxr/usd/usdRender/settings.h>
#include <pxr/usd/usdRender/spec.h>
#include <cstdio>
PXR_NAMESPACE_USING_DIRECTIVE
int main(int argc, char** argv) {
  auto stage = UsdStage::Open(argv[1]);
  if (!stage) return 1;
  for (const UsdPrim& prim : stage->Traverse()) {
    UsdRenderSettings rs(prim);
    if (!rs) continue;
    const UsdRenderSpec spec = UsdRenderComputeSpec(rs, {});
    std::printf("settings %s purposes", prim.GetPath().GetText());
    for (auto& t : spec.includedPurposes) std::printf(" %s", t.GetText());
    std::printf("\n");
    for (const auto& p : spec.products) {
      std::printf("product %s camera %s res %d %d par %.9g policy %s aperture %.9g %.9g "
                  "dw %.9g %.9g %.9g %.9g mb %d dof %d vars",
                  p.renderProductPath.GetText(), p.cameraPath.GetText(), p.resolution[0],
                  p.resolution[1], p.pixelAspectRatio, p.aspectRatioConformPolicy.GetText(),
                  p.apertureSize[0], p.apertureSize[1], p.dataWindowNDC.GetMin()[0],
                  p.dataWindowNDC.GetMin()[1], p.dataWindowNDC.GetMax()[0],
                  p.dataWindowNDC.GetMax()[1], int(p.disableMotionBlur),
                  int(p.disableDepthOfField));
      for (size_t i : p.renderVarIndices)
        std::printf(" %s", spec.renderVars[i].renderVarPath.GetText());
      std::printf("\n");
    }
  }
  return 0;
}
