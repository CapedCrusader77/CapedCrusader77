<div align="center">
  <img src="https://raw.githubusercontent.com/CapedCrusader77/CapedCrusader77/feat/neural-control-lab/capedcrusader77-neural-lab.gif" alt="CapedCrusader77 - Neural Control Lab Interface" width="100%" />

  <br /><br />

  <code>[ NEURAL CORE: ONLINE ]</code> &nbsp;•&nbsp;
  <code>[ ROS2 // ACTIVE ]</code> &nbsp;•&nbsp;
  <code>[ EDGE INFERENCE: 3.2ms ]</code> &nbsp;•&nbsp;
  <code>[ CUDA 12.4 ]</code> &nbsp;•&nbsp;
  <code>[ BUILD 077 ]</code>

  <br /><br />

  <strong>"Building machines that can perceive, reason, and act."</strong>
</div>

---

### 📡 THE TRI-LOOP PARADIGM

```
┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐
│  01 // PERCEPTION       │     │  02 // REASONING        │     │  03 // ACTION           │
│  Stereo Vision + LiDAR  │ ──► │  Deep RL & World Models │ ──► │  ROS 2 + Real-Time MPC  │
│  PCL · YOLO · 6-DoF     │     │  TensorRT · CUDA · ONNX │     │  Nav2 · MoveIt2 · C++20 │
└─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘
```

I engineer end-to-end autonomous systems bridging deep neural networks with real-time physical robotics. My work focuses on sub-5ms perception pipelines, sensor fusion architectures, and high-frequency control loops deployed directly on edge hardware.

---

### ⚡ SELECTED BUILDS // ACTIVE LOADOUT

<table width="100%">
  <tr>
    <td width="33%" valign="top">
      <h4><code>01 // SENSOR_FUSION_SLAM</code></h4>
      <p><b>Real-time LiDAR-Visual Odometry & Volumetric Mapping</b></p>
      <p>Multi-modal SLAM system combining stereoscopic optical flow with 3D LiDAR point cloud registration for GPS-denied environments.</p>
      <hr />
      <sub><b>STACK:</b> <code>ROS 2</code> · <code>C++20</code> · <code>PCL</code> · <code>Nav2</code> · <code>Eigen</code></sub><br />
      <sub><b>STATUS:</b> <font color="#00f0ff">● ACTIVE</font> // ZERO_DRIFT_MODE</sub>
    </td>
    <td width="33%" valign="top">
      <h4><code>02 // EDGE_TENSOR_VISION</code></h4>
      <p><b>Sub-4ms Zero-Copy Inference Pipeline</b></p>
      <p>Accelerated perception engine for 3D object detection, 6-DoF pose estimation, and depth fusion optimized with TensorRT engines.</p>
      <hr />
      <sub><b>STACK:</b> <code>PyTorch</code> · <code>TensorRT</code> · <code>CUDA</code> · <code>OpenCV</code></sub><br />
      <sub><b>STATUS:</b> <font color="#00f0ff">● ACTIVE</font> // 120 FPS FP16</sub>
    </td>
    <td width="33%" valign="top">
      <h4><code>03 // AUTONOMOUS_POLICY_MPC</code></h4>
      <p><b>Reinforcement Learning & Dynamic Trajectory Planner</b></p>
      <p>Deep policy network paired with nonlinear Model Predictive Control (MPC) for obstacle avoidance in unconstrained environments.</p>
      <hr />
      <sub><b>STACK:</b> <code>Python</code> · <code>Isaac Sim</code> · <code>MPC</code> · <code>ROS 2</code></sub><br />
      <sub><b>STATUS:</b> <font color="#8b5cf6">● TRAINING</font> // SIM2REAL</sub>
    </td>
  </tr>
</table>

---

### 📝 FIELD NOTES // RESEARCH & WRITEUPS

- `[EDGE AI]` **Sub-4ms Perception on Jetson Orin** · Zero-copy IPC, unified memory optimization, and TensorRT FP16 quantization.
- `[SENSOR FUSION]` **Extrinsic Calibration of Stereo & LiDAR** · Spatial alignment, timestamp synchronization, and ray-casting projection.
- `[ROS 2 ARCHITECTURE]` **Deterministic Real-Time Pipelines** · Profiling intra-process zero-copy transport on CycloneDDS and PREEMPT_RT.
- `[WORLD MODELS]` **Latent Spatial Prediction for Autonomy** · Self-supervised state estimation for robot navigation in dynamic scenes.

---

### 📊 SYSTEM TELEMETRY // LIVE METRICS

<table>
  <tr>
    <td width="50%" valign="top">
      <code>~/stats $ ./metrics --live</code>
      <br /><br />
      <b>PRIMARY COMPUTE FOCUS</b>
      <pre>
Python      ████████████████████░░░░  68%
C++20       ██████████░░░░░░░░░░░░░░  22%
CUDA / C    ████░░░░░░░░░░░░░░░░░░░░  10%
      </pre>
      <b>CORE SUBSYSTEMS</b>
      <pre>
Autonomous Systems : [████████████████████] 100%
Computer Vision    : [██████████████████░░]  90%
Deep Learning / RL : [████████████████░░░░]  80%
Embedded / Jetson  : [██████████████░░░░░░]  70%
      </pre>
    </td>
    <td width="50%" valign="top">
      <code>~/ops $ tail -f telemetry.log</code>
      <br /><br />
      <pre>
[BOOT] System: Neural Control Lab v2.8.4
[SYNC] Stereo camera: 120mm baseline @ 1080p60
[SYNC] LiDAR: 128-beam sensor stream [ACTIVE]
[CUDA] Allocated device memory: 4.8 GB
[TRT]  Loaded engine: yolov11_perception.plan
[PERC] Inference latency: 3.2ms (Zero-Copy)
[ROS2] Active nodes: /camera /lidar /nav2 /mpc
[STAT] Perception-Action loop: LOCKED
[STAT] All subsystems: NOMINAL
      </pre>
    </td>
  </tr>
</table>

---

### 🛠️ TECHNICAL ARSENAL

<table>
  <tr>
    <td width="25%" valign="top">
      <b>Core Languages</b><br />
      • <code>C++20 / C++17</code><br />
      • <code>Python 3.11+</code><br />
      • <code>CUDA C++</code><br />
      • <code>POSIX Shell / Bash</code>
    </td>
    <td width="25%" valign="top">
      <b>AI & Deep Learning</b><br />
      • <code>PyTorch / LibTorch</code><br />
      • <code>TensorRT Optimization</code><br />
      • <code>ONNX Runtime</code><br />
      • <code>Deep RL (PPO / SAC)</code>
    </td>
    <td width="25%" valign="top">
      <b>Robotics & Control</b><br />
      • <code>ROS / ROS 2 (Humble)</code><br />
      • <code>Nav2 (Path Planning)</code><br />
      • <code>MoveIt 2 (Manipulation)</code><br />
      • <code>Isaac Sim & Gazebo</code>
    </td>
    <td width="25%" valign="top">
      <b>Vision & SLAM</b><br />
      • <code>OpenCV & VPI</code><br />
      • <code>Point Cloud Lib (PCL)</code><br />
      • <code>ORB-SLAM3 / RTAB-Map</code><br />
      • <code>Multi-Camera Calibration</code>
    </td>
  </tr>
</table>

---

### 🌐 CONTROL UPLINK & CONNECT

<div align="center">

```
  CAPEDCRUSADER77 // NEURAL CONTROL LAB
  Engineer: Gokul A
  Affiliation: Indian Institute of Technology Madras (IIT Madras)
  Focus: Autonomous Robotics · Computer Vision · Edge AI
```

<a href="https://github.com/CapedCrusader77"><img src="https://img.shields.io/badge/GitHub-CapedCrusader77-00f0ff?style=for-the-badge&logo=github&logoColor=07090e" /></a>
<a href="https://www.linkedin.com/in/gokul-a-2726a4391/"><img src="https://img.shields.io/badge/LinkedIn-Gokul_A-8b5cf6?style=for-the-badge&logo=linkedin&logoColor=white" /></a>
<a href="mailto:25f2008464@ds.study.iitm.ac.in"><img src="https://img.shields.io/badge/Email-IIT_Madras-00f0ff?style=for-the-badge&logo=gmail&logoColor=07090e" /></a>
<a href="https://github.com/CapedCrusader77"><img src="https://img.shields.io/badge/Status-ONLINE-38bdf8?style=for-the-badge" /></a>

<br /><br />

<i>"The best way to predict the future is to build it."</i>

</div>
