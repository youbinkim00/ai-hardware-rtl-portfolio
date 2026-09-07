# Software and Algorithm Optimization

## 1. Quantization

Quantization은 weight와 activation을 더 낮은 precision으로 표현합니다. 저장 용량과 memory bandwidth를 줄이고, target hardware가 지원할 경우 더 작은 multiplier 또는 더 높은 packing 병렬도를 사용할 수 있습니다.

| 구분 | 장점 | 주요 위험 | Hardware 확인 항목 |
|---|---|---|---|
| PTQ | 재학습 비용이 작고 적용이 빠름 | 낮은 bit에서 outlier와 activation 분포에 민감 | Calibration set, scale/zero-point, rounding |
| QAT | Training 중 quantization error를 학습해 accuracy 방어 | 학습 복잡도와 checkpoint 관리 증가 | Fake-quant와 실제 integer datapath 일치 |
| Uniform precision | Control과 datapath가 단순 | 민감 layer에 과도한 손실 가능 | 단일 arithmetic path의 효율 |
| Mixed precision | Accuracy–cost Pareto 개선 가능 | Datapath, packing, scale와 scheduling 복잡 | 각 bit width가 실제 hardware에 효율적인지 |
| Per-channel | Weight quantization 정확도에 유리 | Scale 저장·적용 비용 증가 | Scale delivery와 requantization 구조 |
| Per-tensor | 구현과 parameter 관리가 단순 | Channel별 dynamic range 차이에 불리 | Overflow와 saturation 분포 |

[Jacob et al.](https://openaccess.thecvf.com/content_cvpr_2018/html/Jacob_Quantization_and_Training_CVPR_2018_paper.html)은 weight와 activation의 integer-only inference를 training procedure와 연결했습니다. [HAQ](https://openaccess.thecvf.com/content_CVPR_2019/html/Wang_HAQ_Hardware-Aware_Automated_Quantization_With_Mixed_Precision_CVPR_2019_paper.html)는 FLOPs 같은 proxy만이 아니라 target hardware latency와 energy feedback을 bit-width 선택에 사용합니다.

### 검증해야 할 수치 계약

```text
float/QAT value
 → scale and zero-point or fixed-point transform
 → rounding rule
 → saturation/clipping
 → signed integer representation
 → packed stream order
 → RTL result
```

QAT accuracy만 맞아도 RTL equivalence가 보장되지는 않습니다. 위 단계 중 하나라도 software와 hardware가 다르면 bit-exact mismatch가 발생합니다.

## 2. Pruning and sparsity

Pruning은 중요도가 낮은 weight, channel 또는 block을 제거합니다.

| 방식 | Software 관점 | Hardware 관점 |
|---|---|---|
| Unstructured pruning | 높은 sparsity를 얻기 쉬움 | Index/metadata, irregular fetch와 load imbalance 필요 |
| Channel/filter pruning | 기존 dense operator로 실행하기 쉬움 | Shape 감소가 실제 latency·memory 감소로 연결되기 쉬움 |
| Block/N:M sparsity | 정확도와 규칙성의 절충 | 규칙에 맞는 sparse datapath가 필요 |
| Activation sparsity | 입력에 따라 동적으로 발생 | Zero detection, gating과 workload 편차 고려 |

[Deep Compression](https://arxiv.org/abs/1510.00149)은 pruning, trained quantization과 entropy coding을 결합했습니다. [SCNN](https://research.nvidia.com/publication/2017-06_scnn-accelerator-compressed-sparse-convolutional-neural-networks)은 sparse weight와 activation을 compressed domain에서 처리하는 별도 dataflow를 제시합니다. 핵심 교훈은 **sparsity 수치만으로 hardware speedup을 주장할 수 없다는 것**입니다.

## 3. Knowledge distillation

Knowledge distillation은 큰 teacher의 output distribution 또는 intermediate representation을 student 학습에 사용합니다. Architecture를 직접 가속하는 기법이라기보다 작은 모델 또는 저정밀 모델의 accuracy recovery 수단입니다.

- 이득: 동일 deployment graph의 accuracy 회복 가능
- 비용: Teacher inference와 loss 설계, training 시간이 증가
- 검증: Teacher가 아니라 최종 student의 독립 test accuracy와 hardware cost 측정

기본 개념은 Hinton et al.의 [Distilling the Knowledge in a Neural Network](https://arxiv.org/abs/1503.02531)을 참고합니다.

## 4. Low-rank decomposition and operator transformation

Weight tensor를 더 작은 행렬/연산의 조합으로 근사하거나 expensive operator를 hardware-friendly operator로 바꿉니다.

- 장점: MAC와 parameter 감소 가능
- 위험: 중간 tensor와 layer launch가 늘어 memory traffic이 증가할 수 있음
- 필수 비교: FLOPs뿐 아니라 intermediate traffic, schedule, accuracy와 post-route throughput

## 5. Efficient architecture and hardware-aware NAS

Depthwise convolution, bottleneck block 또는 grouped operator를 사용하는 efficient model은 연산량을 낮출 수 있습니다. 그러나 arithmetic intensity가 낮아지거나 layer shape가 다양해지면 기존 accelerator utilization이 떨어질 수 있습니다.

[ProxylessNAS](https://arxiv.org/abs/1812.00332)는 target hardware metric을 search에 직접 포함합니다. 여기서 중요한 원칙은 “작은 모델”과 “target hardware에서 빠른 모델”이 항상 같지 않다는 점입니다.

## 6. Software optimization acceptance criteria

- 동일 dataset split과 metric으로 accuracy 비교
- Parameter/MAC 감소와 measured latency를 분리
- Target hardware가 precision/sparsity/operator를 실제 지원하는지 확인
- 변환 전후 graph와 numeric contract 기록
- Accuracy 회복 비용까지 포함한 ablation
- 최종 deployed artifact의 hash와 evaluation path 보존
