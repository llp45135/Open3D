//
// Created by wei on 10/16/18.
//

#pragma once

#include "MarchingCubesConstCuda.h"
#include "UniformMeshVolumeCuda.h"
#include "UniformTSDFVolumeCuda.cuh"
#include <Core/Core.h>

namespace open3d {
/**
 * Server end
 */
template<VertexType type, size_t N>
__device__
void UniformMeshVolumeCudaServer<type, N>::AllocateVertex(
    const Vector3i &&X,
    UniformTSDFVolumeCudaServer<N> &tsdf_volume) {

    uchar &table_index = table_indices(X);
    table_index = 0;

    int tmp_table_index = 0;

    /** There are early returns. #pragma unroll SLOWS it down **/
    for (size_t corner = 0; corner < 8; ++corner) {
        Vector3i X_corner = Vector3i(X(0) + shift[corner][0],
                                     X(1) + shift[corner][1],
                                     X(2) + shift[corner][2]);

        uchar weight = tsdf_volume.weight(X_corner);
        if (weight == 0) return;

        float tsdf = tsdf_volume.tsdf(X_corner);
        if (fabsf(tsdf) > 2 * tsdf_volume.voxel_length_) return;

        tmp_table_index |= ((tsdf < 0) ? (1 << corner) : 0);
    }
    if (tmp_table_index == 0 || tmp_table_index == 255) return;
    table_index = (uchar) tmp_table_index;

    /** Tell them they will be extracted. Conflict can be ignored **/
    int edges = edge_table[table_index];
#pragma unroll 12
    for (size_t edge = 0; edge < 12; ++edge) {
        if (edges & (1 << edge)) {
            Vector3i X_edge_holder = Vector3i(X(0) + edge_shift[edge][0],
                                              X(1) + edge_shift[edge][1],
                                              X(2) + edge_shift[edge][2]);
            vertex_indices(X_edge_holder)(edge_shift[edge][3]) =
                VERTEX_TO_ALLOCATE;
        }
    }
}

template<VertexType type, size_t N>
__device__
void UniformMeshVolumeCudaServer<type, N>::ExtractVertex(
    const Vector3i &&X,
    UniformTSDFVolumeCudaServer<N> &tsdf_volume) {

    Vector3i &vertex_index = vertex_indices(X);
    if (vertex_index(0) != VERTEX_TO_ALLOCATE
        && vertex_index(1) != VERTEX_TO_ALLOCATE
        && vertex_index(2) != VERTEX_TO_ALLOCATE)
        return;

    Vector3i axis_offset = Vector3i::Zeros();

    float tsdf_0 = tsdf_volume.tsdf(X);
    Vector3f gradient_0 = tsdf_volume.gradient(X);

#pragma unroll 1
    for (size_t axis = 0; axis < 3; ++axis) {
        if (vertex_index(axis) == VERTEX_TO_ALLOCATE) {
            axis_offset(axis) = 1;
            Vector3i X_axis = X + axis_offset;

            float tsdf_i = tsdf_volume.tsdf(X_axis);
            float mu = (0 - tsdf_0) / (tsdf_i - tsdf_0);

            vertex_index(axis) = mesh_.vertices().push_back(
                tsdf_volume.voxelf_to_world(
                    Vector3f(X(0) + mu * axis_offset(0),
                             X(1) + mu * axis_offset(1),
                             X(2) + mu * axis_offset(2))));

            /** Note we share the vertex indices **/
            if (type & VertexWithNormal) {
                mesh_.vertex_normals()[vertex_index(axis)] =
                    tsdf_volume.transform_volume_to_world_.Rotate(
                        (1 - mu) * gradient_0
                            + mu * tsdf_volume.gradient(X_axis));
            }

            axis_offset(axis) = 0;
        }
    }
}

template<VertexType type, size_t N>
__device__
inline void UniformMeshVolumeCudaServer<type, N>::ExtractTriangle(
    const Vector3i &&X) {

    const uchar table_index = table_indices(X);
    if (table_index == 0 || table_index == 255) return;

    for (int tri = 0; tri < 16; tri += 3) {
        if (tri_table[table_index][tri] == -1) return;

        /** Edge index -> neighbor cube index ([0, 1])^3 x vertex index (3) **/
        Vector3i tri_vertex_indices;
#pragma unroll 1
        for (int vertex = 0; vertex < 3; ++vertex) {
            /** Edge index **/
            int edge_j = tri_table[table_index][tri + vertex];
            Vector3i X_edge_j_holder = Vector3i(X(0) + edge_shift[edge_j][0],
                                                X(1) + edge_shift[edge_j][1],
                                                X(2) + edge_shift[edge_j][2]);
            tri_vertex_indices(vertex) =
                vertex_indices(X_edge_j_holder)(edge_shift[edge_j][3]);
        }
        mesh_.triangles().push_back(tri_vertex_indices);
    }
}

/**
 * Client end
 */
template<VertexType type, size_t N>
UniformMeshVolumeCuda<type, N>::UniformMeshVolumeCuda() {
    max_vertices_ = -1;
    max_triangles_ = -1;
}

template<VertexType type, size_t N>
UniformMeshVolumeCuda<type, N>::UniformMeshVolumeCuda(
    int max_vertices, int max_triangles) {
    Create(max_vertices, max_triangles);
}

template<VertexType type, size_t N>
UniformMeshVolumeCuda<type, N>::UniformMeshVolumeCuda(
    const UniformMeshVolumeCuda<type, N> &other) {
    max_vertices_ = other.max_vertices_;
    max_triangles_ = other.max_triangles_;

    server_ = other.server();
    mesh_ = other.mesh();
}

template<VertexType type, size_t N>
UniformMeshVolumeCuda<type, N> &UniformMeshVolumeCuda<type, N>::operator=(
    const UniformMeshVolumeCuda<type, N> &other) {
    if (this != &other) {
        max_vertices_ = other.max_vertices_;
        max_triangles_ = other.max_triangles_;

        server_ = other.server();
        mesh_ = other.mesh();
    }
    return *this;
}

template<VertexType type, size_t N>
UniformMeshVolumeCuda<type, N>::~UniformMeshVolumeCuda() {
    Release();
}

template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::Create(
    int max_vertices, int max_triangles) {
    if (server_ != nullptr) {
        PrintError("Already created. Stop re-creating!\n");
        return;
    }

    assert(max_vertices > 0 && max_triangles > 0);

    server_ = std::make_shared<UniformMeshVolumeCudaServer<type, N>>();
    max_triangles_ = max_triangles;
    max_vertices_ = max_vertices;

    const int NNN = N * N * N;
    CheckCuda(cudaMalloc(&server_->table_indices_, sizeof(uchar) * NNN));
    CheckCuda(cudaMalloc(&server_->vertex_indices_, sizeof(Vector3i) * NNN));
    mesh_.Create(max_vertices_, max_triangles_);

    UpdateServer();
    Reset();
}

template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::Release() {
    if (server_ != nullptr && server_.use_count() == 1) {
        CheckCuda(cudaFree(server_->table_indices_));
        CheckCuda(cudaFree(server_->vertex_indices_));
    }
    mesh_.Release();
    server_ = nullptr;
    max_vertices_ = -1;
    max_triangles_ = -1;
}

/** Reset only have to be performed once on initialization:
 * 1. table_indices_ will be reset in kernels;
 * 2. None of the vertex_indices_ will be -1 after this reset, because
 *  - The not effected vertex indices will remain 0;
 *  - The effected vertex indices will be >= 0 after being assigned address.
 **/
template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::Reset() {
    if (server_ != nullptr) {
        const size_t NNN = N * N * N;
        CheckCuda(cudaMemset(server_->table_indices_, 0,
                             sizeof(uchar) * NNN));
        CheckCuda(cudaMemset(server_->vertex_indices_, 0,
                             sizeof(Vector3i) * NNN));
        mesh_.Reset();
    }
}

template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::UpdateServer() {
    if (server_ != nullptr) {
        server_->mesh_ = *mesh_.server();
    }
}

template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::VertexAllocation(
    UniformTSDFVolumeCuda<N> &tsdf_volume) {

    Timer timer;
    timer.Start();

    const int num_blocks = DIV_CEILING(N, THREAD_3D_UNIT);
    const dim3 blocks(num_blocks, num_blocks, num_blocks);
    const dim3 threads(THREAD_3D_UNIT, THREAD_3D_UNIT, THREAD_3D_UNIT);
    MarchingCubesVertexAllocationKernel << < blocks, threads >> > (
        *server_, *tsdf_volume.server());
    CheckCuda(cudaDeviceSynchronize());
    CheckCuda(cudaGetLastError());

    timer.Stop();
    PrintInfo("Allocation takes %f milliseconds\n", timer.GetDuration());
}

template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::VertexExtraction(
    UniformTSDFVolumeCuda<N> &tsdf_volume) {

    Timer timer;
    timer.Start();

    const int num_blocks = DIV_CEILING(N, THREAD_3D_UNIT);
    const dim3 blocks(num_blocks, num_blocks, num_blocks);
    const dim3 threads(THREAD_3D_UNIT, THREAD_3D_UNIT, THREAD_3D_UNIT);
    MarchingCubesVertexExtractionKernel << < blocks, threads >> > (
        *server_, *tsdf_volume.server());
    CheckCuda(cudaDeviceSynchronize());
    CheckCuda(cudaGetLastError());

    timer.Stop();
    PrintInfo("Extraction takes %f milliseconds\n", timer.GetDuration());
}

template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::TriangleExtraction() {

    Timer timer;
    timer.Start();

    const int num_blocks = DIV_CEILING(N, THREAD_3D_UNIT);
    const dim3 blocks(num_blocks, num_blocks, num_blocks);
    const dim3 threads(THREAD_3D_UNIT, THREAD_3D_UNIT, THREAD_3D_UNIT);
    MarchingCubesTriangleExtractionKernel << < blocks, threads >> > (*server_);
    CheckCuda(cudaDeviceSynchronize());
    CheckCuda(cudaGetLastError());

    timer.Stop();
    PrintInfo("Triangulation takes %f milliseconds\n", timer.GetDuration());
}

template<VertexType type, size_t N>
void UniformMeshVolumeCuda<type, N>::MarchingCubes(
    UniformTSDFVolumeCuda<N> &tsdf_volume) {

    mesh_.Reset();

    VertexAllocation(tsdf_volume);
    VertexExtraction(tsdf_volume);

    TriangleExtraction();

    if (type & VertexWithNormal) {
        mesh_.vertex_normals().set_size(mesh_.vertices().size());
    }
    if (type & VertexWithColor) {
        mesh_.vertex_colors().set_size(mesh_.vertices().size());
    }
}
}