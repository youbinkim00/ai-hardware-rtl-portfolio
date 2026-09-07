# Software–RTL Numeric Contract

## Why a numeric contract is required

Floating-point PyTorch 출력과 RTL 출력을 바로 비교하면 quantization, rounding과 saturation 차이가 섞여 RTL 오류인지 모델 변환 오차인지 구분하기 어렵습니다. 따라서 비교 기준은 floating model이 아니라 RTL 규칙을 그대로 실행하는 integer reference입니다.

## Contract items

각 tensor 경계에서 다음 정보를 명시합니다.

| 항목 | 검증 질문 |
|---|---|
| Bit width | 입력·weight·accumulator·output 폭이 동일한가? |
| Signedness | signed extension과 comparison이 동일한가? |
| Scale | QAT scale이 RTL fixed-point parameter로 정확히 변환되는가? |
| Rounding | shift 전 bias와 음수 처리 순서가 동일한가? |
| Saturation | overflow 시 wrap이 아니라 목표 범위로 clamp되는가? |
| Packing | byte/nibble 및 lane 순서가 동일한가? |

개념적 requantization은 다음과 같이 표현할 수 있습니다.

```text
accumulator
    → integer multiply
    → rounding adjustment
    → arithmetic shift
    → zero-point/bias adjustment
    → saturation
    → packed output
```

실제 multiplier, shift, threshold와 layer parameter는 공개하지 않습니다.

## Golden-vector generation controls

- Export source checkpoint와 hash 기록
- Tensor shape 및 element count 검사
- Signed integer 범위 검사
- Layer별 input/weight/parameter/output manifest 생성
- Python reference와 RTL packing 순서의 독립 확인
- 하나의 sample이 아닌 복수 VOC 입력으로 regression

## Claim boundary

Integer reference와 RTL의 mismatch 0은 정의한 numeric contract 안에서 RTL이 reference를 재현했다는 뜻입니다. Dataset 전체 정확도, unseen-input robustness 또는 board timing을 단독으로 보증하는 표현으로 확대하지 않습니다.

