# MobileNetV1 Implementation Results

[← MobileNetV1 overview](../README.md)

## Implementation snapshot

Source portfolio의 `This Work` 열에 기록된 결과입니다.

| Metric | Result |
|---|---:|
| Model | MobileNetV1 |
| Device | XCZU9EG |
| Board context | ZCU102 |
| Frequency | 150 MHz |
| Precision | Fixed-8 |
| Image size | 224×224 |
| DSP | 86 |
| BRAM | 489.5 |
| LUT | 171.3K |
| FF | 100K |
| Frame rate | **252.7 FPS** |
| Throughput | **287.6 GOPS** |
| Power | **4.296 W** |
| Power efficiency | **66.9 GOPS/W** |
| Hardware efficiency | **3.34 GOPS/DSP** |

## How to interpret the numbers

- Frame rate / throughput는 accelerator implementation result
- Power는 source portfolio의 Vivado-based implementation comparison에 기록된 값
- PYNQ classification demo는 system integration evidence
- PYNQ application의 capture/preprocess/display를 포함한 end-to-end FPS와 accelerator FPS를 같은 값으로 표현하지 않음

## Design-level evidence

Source portfolio에는 다음 추가 결과가 기록되어 있습니다.

- PE utilization: **98.64%**
- sliding-window pipeline result: **250 FPS**
- comparison baseline 대비 energy efficiency: **1.35×**
- comparison baseline 대비 DSP efficiency: **1.57×**

논문용 proposed architecture/timing figure는 public repository에서 제외합니다.

## Reproducibility boundary

본 public portfolio에는 full Vivado project, bitstream, checkpoint, RTL source를 포함하지 않으므로 위 결과를 독립 재현 가능한 benchmark로 표현하지 않습니다.  
이 수치는 source portfolio에 기록된 project implementation evidence의 요약입니다.
