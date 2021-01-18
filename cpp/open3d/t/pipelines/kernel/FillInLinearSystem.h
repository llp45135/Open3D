// ----------------------------------------------------------------------------
// -                        Open3D: www.open3d.org                            -
// ----------------------------------------------------------------------------
// The MIT License (MIT)
//
// Copyright (c) 2018 www.open3d.org
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
// ----------------------------------------------------------------------------

#include "open3d/core/CUDAUtils.h"
#include "open3d/core/Tensor.h"
namespace open3d {
namespace t {
namespace pipelines {
namespace kernel {

void FillInRigidAlignmentTerm(core::Tensor &AtA,
                              core::Tensor &Atb,
                              core::Tensor &residual,
                              const core::Tensor &points_i,
                              const core::Tensor &points_j,
                              const core::Tensor &normals_i,
                              int i,
                              int j);

void FillInSLACAlignmentTerm(core::Tensor &AtA,
                             core::Tensor &Atb,
                             core::Tensor &residual,
                             const core::Tensor &points_i,
                             const core::Tensor &points_j,
                             const core::Tensor &normals_i,
                             core::Tensor &cgrid_nb_indices_i,
                             core::Tensor &cgrid_nb_indices_j,
                             core::Tensor &cgrid_nb_interp_ratios_i,
                             core::Tensor &cgrid_nb_interp_ratios_j,
                             core::Tensor &cgrid_positions,
                             core::Tensor &R_i_transpose,
                             core::Tensor &R_j_transpose,
                             int i,
                             int j);

void FillInRigidAlignmentTermCPU(core::Tensor &AtA,
                                 core::Tensor &Atb,
                                 core::Tensor &residual,
                                 const core::Tensor &points_i,
                                 const core::Tensor &points_j,
                                 const core::Tensor &normals_i,
                                 int i,
                                 int j);

void FillInSLACAlignmentTermCPU(core::Tensor &AtA,
                                core::Tensor &Atb,
                                core::Tensor &residual,
                                const core::Tensor &points_i,
                                const core::Tensor &points_j,
                                const core::Tensor &normals_i,
                                core::Tensor &cgrid_nb_indices_i,
                                core::Tensor &cgrid_nb_indices_j,
                                core::Tensor &cgrid_nb_interp_ratios_i,
                                core::Tensor &cgrid_nb_interp_ratios_j,
                                core::Tensor &cgrid_positions,
                                core::Tensor &R_i_transpose,
                                core::Tensor &R_j_transpose,
                                int i,
                                int j);
#ifdef BUILD_CUDA_MODULE
void FillInRigidAlignmentTermCUDA(core::Tensor &AtA,
                                  core::Tensor &Atb,
                                  core::Tensor &residual,
                                  const core::Tensor &points_i,
                                  const core::Tensor &points_j,
                                  const core::Tensor &normals_i,
                                  int i,
                                  int j);

void FillInSLACAlignmentTermCUDA(core::Tensor &AtA,
                                 core::Tensor &Atb,
                                 core::Tensor &residual,
                                 const core::Tensor &points_i,
                                 const core::Tensor &points_j,
                                 const core::Tensor &normals_i,
                                 core::Tensor &cgrid_nb_indices_i,
                                 core::Tensor &cgrid_nb_indices_j,
                                 core::Tensor &cgrid_nb_interp_ratios_i,
                                 core::Tensor &cgrid_nb_interp_ratios_j,
                                 core::Tensor &cgrid_positions,
                                 core::Tensor &R_i_transpose,
                                 core::Tensor &R_j_transpose,
                                 int i,
                                 int j);
#endif

}  // namespace kernel
}  // namespace pipelines
}  // namespace t
}  // namespace open3d
