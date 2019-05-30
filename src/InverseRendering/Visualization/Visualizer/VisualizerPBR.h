//
// Created by wei on 4/15/19.
//

#pragma once

#include <Open3D/Open3D.h>
#include <InverseRendering/Geometry/Lighting.h>
#include <InverseRendering/Visualization/Shader/LightingPreprocessRenderer.h>
#include "RenderOptionWithLighting.h"

namespace open3d {
namespace visualization {

class VisualizerPBR : public VisualizerWithKeyCallback {
public:
    /** Handle geometry (including textures) **/
    virtual bool AddGeometry(
        std::shared_ptr<const geometry::Geometry> geometry_ptr) override;

    /** Handling lighting (shared over the visualizer) **/
    virtual bool InitRenderOption() override {
        render_option_ptr_ = std::unique_ptr<RenderOptionWithLighting>(
            new RenderOptionWithLighting);
        return true;
    }

    /** Call this function
     * - AFTER @CreateVisualizerWindow (where @InitRenderOption is called)
     * - BEFORE @Run (or whatever customized rendering task)
     *   Currently we only support one lighting.
     *   It would remove the previous bound lighting.
     * **/
    bool UpdateLighting(
        const std::shared_ptr<const geometry::Lighting> &lighting) {

        /** Single instance of the lighting preprocessor **/
        if (light_preprocessing_renderer_ptr_ == nullptr) {
            light_preprocessing_renderer_ptr_ =
                std::make_shared<glsl::LightingPreprocessRenderer>();
        }

        auto &render_option_with_lighting_ptr =
            (std::unique_ptr<RenderOptionWithLighting> &) render_option_ptr_;
        light_preprocessing_renderer_ptr_->AddGeometry(lighting);
        bool success = light_preprocessing_renderer_ptr_->RenderToOption(
            *render_option_with_lighting_ptr, *view_control_ptr_);

        return true;
    }

    /** This specific renderer:
     * 1. Preprocess input HDR lighting image,
     * 2. Maintain textures, (updated to RenderOption instantly),
     * 3. Destroy context on leave. **/
    std::shared_ptr<glsl::LightingPreprocessRenderer>
        light_preprocessing_renderer_ptr_ = nullptr;
};


}  // namespace visualization
}  // namespace open3d
