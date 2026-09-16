# Engineering Evidence Images

이 디렉터리는 개념 infographic가 아니라 실제 설계·검증·system-demo 환경에서 얻은 공개 가능한 screenshot/photo를 보관합니다.

## YOLOv5s

- `axi_vip_block_design.png` — Vivado AXI VIP verification Block Design
- `zcu104_axi_dma_block_design.png` — ZCU104 PS/PL + AXI DMA integration Block Design
- `yolov5s_zcu104_pynq_demo.png` — ZCU104 PYNQ object-detection demo photo

## MobileNetV1

- `mobilenet_zcu102_block_design.png` — ZCU102 AXI/DMA/FIFO + MobileNetV1 system integration Block Design
- `mobilenet_pynq_sw_hw_system.png` — source portfolio의 PYNQ software/hardware integration figure

## Evidence policy

- 실제 tool screenshot/photo로 대체 가능한 system/verification evidence는 conceptual infographic보다 우선 사용
- MobileNet manuscript novelty에 해당하는 proposed architecture / adaptive parallelism / line-buffer / memory-hierarchy / pipeline timing figure는 이 public repository에 복사하지 않음
- detailed NPU microarchitecture, generated product, bitstream, DCP는 공개하지 않음
- screenshot의 instance name은 historical naming을 포함할 수 있으므로 board/frequency claim은 문서의 verified result와 함께 해석
- third-party logo/mark는 각 권리자에게 귀속되며, public distribution 전 별도 attribution/license review가 필요한 경우 교체 또는 출처 표기를 수행
