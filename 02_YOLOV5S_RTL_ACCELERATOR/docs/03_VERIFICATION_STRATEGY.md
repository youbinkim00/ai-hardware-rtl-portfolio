# Verification Strategy

## Verification question

검증의 핵심 질문은 “파형이 그럴듯한가?”가 아니라 다음과 같습니다.

> 동일한 quantization contract를 적용했을 때 software integer reference와 RTL의 모든 관찰 가능한 결과가 정확히 일치하는가?

## Reference chain

```text
PyTorch/QAT checkpoint
        ↓
RTL arithmetic contract
bit width · signedness · rounding · saturation
        ↓
Integer reference execution
        ↓
Layer input/parameter/golden vector
        ↓
SystemVerilog scoreboard
        ↓
Per-layer and end-to-end PASS/FAIL
```

## Automated regression

테스트벤치는 계층별 expected count와 actual count를 확인하고, mismatch 위치와 값을 자동 기록합니다. 조건부 verification mode를 사용해 production behavior를 유지하면서 검증 시에만 필요한 관찰과 비교를 활성화합니다.

검증된 공개 지표는 다음과 같습니다.

| 항목 | 결과 |
|---|---:|
| Regression inputs | VOC 이미지 10종 |
| Detection raw outputs per image | 100,800 |
| Full-layer/output mismatch | 0 |

## Acceptance policy

- 한 입력의 PASS를 전체 기능 보증으로 확대 해석하지 않음
- count가 맞아도 data mismatch가 있으면 FAIL
- data가 맞아도 protocol violation이 있으면 FAIL
- RTL 변경 후 영향 범위에 맞는 regression을 다시 수행
- PPA가 개선돼도 기능 결과가 달라지면 변경을 채택하지 않음

## Public evidence

현재 repository에서 공개하고 있는 verification evidence:

- regression input 수, detection raw-output count와 mismatch 결과
- scoreboard의 count/data acceptance policy
- architecture를 노출하지 않는 독립 `scoreboard_skeleton.sv`
- AXI4-Stream stall payload를 검사하는 `axi_stream_stability_checker.sv`
- 실제 AXI VIP Block Design
- AXI VIP stress 조건과 output-beat/handshake 검증 결과

전체 golden vector, private hierarchy와 parameter payload는 공개하지 않습니다.

추가 visual evidence가 확보되면 별도 artifact로 둘 수 있는 항목은 representative layer-compare 화면, annotated backpressure waveform과 scoreboard PASS summary입니다. 이들은 현재 검증 결과의 성립 조건이 아니라 **추가 공개 자료**입니다.
