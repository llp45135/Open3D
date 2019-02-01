//
// Created by wei on 11/28/18.
//

#pragma once

#include <string>
#include <sstream>
#include <fstream>
#include <vector>

#include <Core/Core.h>
#include <Visualization/Visualization.h>

std::vector<std::pair<std::string, std::string>>
ReadDataAssociation(const std::string &association_path) {
    std::vector<std::pair<std::string, std::string>> filenames;

    std::ifstream fin(association_path);
    if (!fin.is_open()) {
        open3d::PrintError("Cannot open file %s, abort.\n",
                           association_path.c_str());
        return filenames;
    }

    std::string depth_path;
    std::string image_path;
    while (fin >> depth_path >> image_path) {
        filenames.emplace_back(std::make_pair(depth_path, image_path));
    }

    return filenames;
}

std::shared_ptr<open3d::RGBDImage> ReadRGBDImage(
    const std::string &color_filename,
    const std::string &depth_filename,
    const open3d::PinholeCameraIntrinsic &intrinsic,
    double depth_scale = 1000.0) {

    using namespace open3d;
    Image color, depth;
    ReadImage(color_filename, color);
    ReadImage(depth_filename, depth);

    PrintDebug("Reading RGBD image : \n");
    PrintDebug("     Color : %d x %d x %d (%d bits per channel)\n",
        color.width_, color.height_,
        color.num_of_channels_, color.bytes_per_channel_ * 8);
    PrintDebug("     Depth : %d x %d x %d (%d bits per channel)\n",
        depth.width_, depth.height_,
        depth.num_of_channels_, depth.bytes_per_channel_ * 8);

    double depth_trunc = 4.0;
    bool convert_rgb_to_intensity = true;
    std::shared_ptr<RGBDImage> rgbd_image = CreateRGBDImageFromColorAndDepth(
        color, depth, depth_scale, depth_trunc,
        convert_rgb_to_intensity);

    return rgbd_image;
}

void VisualizeRegistration(const open3d::PointCloud &source,
                           const open3d::PointCloud &target,
                           const Eigen::Matrix4d &Transformation) {
    using namespace open3d;
    std::shared_ptr<PointCloud> source_transformed_ptr(new PointCloud);
    std::shared_ptr<PointCloud> target_ptr(new PointCloud);
    *source_transformed_ptr = source;
    *target_ptr = target;
    source_transformed_ptr->Transform(Transformation);
    DrawGeometries({source_transformed_ptr, target_ptr}, "Open3D");
}

std::shared_ptr<open3d::Feature> PreprocessPointCloud(open3d::PointCloud &pcd) {
    using namespace open3d;
    EstimateNormals(pcd, open3d::KDTreeSearchParamHybrid(0.1, 30));
    auto pcd_fpfh = ComputeFPFHFeature(
        pcd, open3d::KDTreeSearchParamHybrid(0.25, 100));
    return pcd_fpfh;
}
