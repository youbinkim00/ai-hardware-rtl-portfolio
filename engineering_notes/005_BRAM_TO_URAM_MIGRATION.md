# 005 — BRAM-to-URAM Migration Without Breaking Functionality

## Migration rule

메모리 종류는 바꾸되 controller가 기대하는 interface contract는 유지합니다.

```text
address timing
write-enable timing
read-enable timing
read-data latency
collision semantics
reset behavior
```

## Safe sequence

1. 기존 BRAM wrapper의 cycle contract 기록
2. 동일 port signature를 가진 URAM wrapper 작성
3. URAM 내부 pipeline으로 기존 read latency 재현
4. Small deterministic test로 first/middle/last address 확인
5. Layer boundary regression
6. Full-network golden regression
7. Synthesis에서 URAM mapping 확인

## Failure pattern

가장 위험한 오류는 대부분의 값은 맞지만 마지막 word 또는 다음 layer 첫 word만 어긋나는 경우입니다. 이는 read latency, valid alignment 또는 enable hold가 한 cycle 차이 나는 신호일 수 있습니다.

Optimization을 유지하면서 수정하려면 enable 억제를 제거해 문제를 숨기기보다, data-valid pipeline과 final-beat drain 조건을 메모리 latency에 맞춰 정렬해야 합니다.

