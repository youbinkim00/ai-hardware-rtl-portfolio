# Model Preservation and Hardware Contribution

## 핵심 질문

> 새로운 detection network를 제안하지 않았다면, 이 프로젝트의 연구·설계 기여는 무엇인가?

이 프로젝트는 algorithm novelty와 hardware architecture novelty를 의도적으로 분리했습니다. 검증된 YOLOv5s 계열 workload의 주요 graph를 유지한 상태에서, 이를 저정밀 정수 RTL로 실현할 때 발생하는 compute·memory·control 문제를 architecture와 scheduling으로 해결하는 것이 목표입니다.

모델을 유지했다는 사실 자체가 novelty는 아닙니다. 그러나 모델을 임의로 작게 만들어 난도를 제거하지 않았기 때문에, 측정되는 하드웨어 결과의 원인을 더 명확하게 설명할 수 있고 실제 detector graph의 이질성과 dependency를 설계 문제로 보존할 수 있습니다.

## 무엇을 유지했고 무엇을 변경했는가

| 구분 | 본 프로젝트의 선택 | 이유 |
|---|---|---|
| 주요 backbone·neck 흐름 | 과도한 layer 제거 없이 유지 | 모델 축소 효과와 architecture 효과의 혼동 방지 |
| residual·concatenation·upsampling | graph dependency로 유지 | 실제 intermediate lifetime과 branch scheduling 문제 보존 |
| multi-scale detection | 세 output scale의 흐름 유지 | 단일 출력 toy accelerator로 축소하지 않기 위함 |
| Dataset/class contract | VOC20으로 변경 | 목표 응용과 공개 benchmark에 맞춤 |
| Activation·quantization | RTL 친화적 저정밀 정수 규칙으로 변경 | bit-exact datapath 구현과 검증을 위한 명시적 수치 계약 |
| Host post-processing | PS software 경계로 분리 | raw hardware output과 detection 후처리의 책임 구분 |

따라서 정확한 명칭은 **YOLOv5s-derived VOC20 low-precision RTL accelerator**입니다. “Ultralytics의 공식 COCO checkpoint를 수정 없이 그대로 구현했다”는 표현은 사용하지 않습니다.

## 왜 이 선택이 공정한가

### Architecture 효과를 분리한다

Layer 또는 channel을 크게 줄이면 latency, memory와 resource가 함께 줄어듭니다. 그 결과가 model compression 때문인지 RTL dataflow 때문인지 분리하기 어렵습니다. 주요 graph를 유지하면 hardware scheduling, reuse, prefetch와 shared compute가 만든 효과를 별도의 baseline과 비교할 수 있는 조건이 만들어집니다.

### 실제 하드웨어 난도를 보존한다

YOLOv5s 계열 graph는 layer shape가 일정하지 않고 residual, concatenation, upsampling과 multi-scale head를 포함합니다. 이 구조를 유지하면 다음 문제가 남습니다.

- 서로 다른 operator와 shape가 요구하는 병렬도 차이
- producer-consumer와 branch 사이의 데이터 준비 시점
- feature-map lifetime 및 on-chip memory pressure
- 현재 연산과 다음 weight/parameter 준비의 중첩
- row/layer/write completion 사이의 cycle-level 동기화
- 세 detection output의 streaming 및 backpressure 처리

즉, 단순 convolution benchmark가 아니라 전체 detector를 RTL로 닫는 능력을 평가할 수 있습니다.

### 정확도와 하드웨어 효과를 함께 추적한다

저정밀화로 얻은 자원 이득만 제시하지 않고, float/QAT/integer/RTL 단계의 차이를 분리해 기록했습니다. RTL의 rounding, saturation, signedness와 packing까지 software authority에 반영하고, 계층별 golden과 raw head output으로 검증했습니다. 이를 통해 “빠른 회로지만 원래 모델과 다른 계산”이 되는 위험을 줄였습니다.

## 설계의 특별한 장점

### 단일 layer가 아니라 graph 구간을 본다

일반적인 layer-by-layer mapping은 각 layer 내부의 연산 효율은 설명하기 쉽지만, layer boundary의 대기와 intermediate transfer를 놓칠 수 있습니다. 본 설계는 의존 관계가 있는 인접 producer-consumer 또는 branch 구간까지 관찰 범위에 포함하고, 해당 구간의 주 병목에 맞춰 실행 방식을 정합니다.

세부 scheduling rule과 layer mapping은 논문 검토 전 비공개이지만, 공개 가능한 원칙은 다음과 같습니다.

```text
Graph/dependency observation
        ↓
Compute · data-supply · control bottleneck identification
        ↓
Legality check: dependency · buffer · port · completion
        ↓
Fixed compute fabric role/data-path configuration
        ↓
Full-network numeric · protocol · physical verification
```

### 고정 compute fabric의 활용 범위를 넓힌다

Operator마다 전용 engine을 추가하면 특정 구간의 성능은 높일 수 있지만, 사용하지 않는 구간에도 area와 routing 비용이 남습니다. 본 설계는 고정된 compute fabric을 공유하고, workload 구간에 따라 lane role, feature/weight source, reduction과 writeback 동작을 바꾸는 방향을 택했습니다.

이 접근의 장점은 “어떤 mode 이름을 새로 만들었다”는 데 있지 않습니다. 서로 다른 실행 패턴을 실제 memory path와 completion control까지 포함해 하나의 fabric에서 동작하도록 닫았다는 점에 있습니다.

### 데이터 공급과 제어를 연산의 일부로 취급한다

Peak MAC throughput만 높아도 weight나 feature가 늦게 도착하면 PE는 기다립니다. 따라서 본 설계에서는 local buffering, 현재 연산 중 다음 parameter prefetch, backpressure와 completion acknowledge를 계산 schedule과 함께 다룹니다. 기능 오류를 막는 control correctness와 유휴를 줄이는 performance scheduling을 별개 문제로 두지 않았습니다.

### 검증 가능성이 architecture의 일부다

설계의 신뢰성은 SystemVerilog를 사용했다는 사실에서 자동으로 생기지 않습니다. 본 프로젝트는 다음 acceptance chain을 구성했습니다.

```text
QAT checkpoint
 → integer authority model
 → packed input/weight/parameter and layer golden
 → full-layer RTL scoreboard
 → AXI VIP protocol stress
 → DMA/SoC integration
 → routed implementation
```

이 연결 덕분에 문제를 software accuracy, fixed-point semantics, RTL control, AXI protocol 또는 physical design 단계로 분해해 추적할 수 있습니다.

## Novelty claim boundary

### 현재 강하게 말할 수 있는 것

- 주요 detector graph를 보존한 full-network low-precision RTL implementation
- compute·data-supply·control 병목을 함께 다룬 inter-layer scheduling 관점
- 고정 compute fabric에서 여러 실행 역할을 실현한 구체적인 RTL engineering
- integer golden, full-layer regression, AXI stress와 physical implementation을 잇는 end-to-end 검증 흐름

### 추가 실험 전에는 제한해야 하는 것

- streaming, parallelism, pipelining 또는 fusion 각각을 최초로 발명했다는 주장
- 모든 CNN에 자동으로 적용되는 범용 mapper라는 주장
- 공정 baseline 없이 latency·area·energy가 특정 비율 개선됐다는 주장
- YOLOv5s 한 모델의 결과만으로 일반적인 우수성이 증명됐다는 주장
- 실제 board 측정 전의 PYNQ FPS 또는 power 완료 주장

현재 가장 방어 가능한 표현은 다음과 같습니다.

> 검증된 detector graph의 핵심 구조를 과도하게 단순화하지 않고, 인접 graph 구간에서 발생하는 compute·data-supply·control 병목을 고정 compute fabric의 역할·데이터 경로·memory readiness·completion configuration으로 해결한 full-network RTL engineering methodology를 구현하고 검증했습니다.

## 실무 관점의 가치

이 프로젝트의 실무적 강점은 특정 연산기의 RTL 코드만 작성한 것이 아니라 요구사항을 다음 단계까지 연결했다는 점입니다.

- algorithm accuracy와 RTL numeric contract의 연결
- architecture 선택과 buffer/traffic/control 영향의 동시 검토
- 자동 regression으로 기능 변경의 부작용 확인
- AXI stall과 backpressure를 포함한 system boundary 검증
- synthesis 결과뿐 아니라 route, timing과 congestion을 기준으로 최적화 판단
- 완료된 증거와 아직 측정하지 않은 기대 효과의 구분

이는 “YOLO를 구현했다”보다, **복잡한 AI workload를 검증 가능한 반도체 설계 문제로 변환하고 끝까지 닫았다**는 경험을 보여주는 것이 이 저장소의 목적입니다.
