# Sliding-window Pipeline

## Sequential execution limitation

DWC 결과 feature map 전체가 끝난 뒤 PWC를 시작하면 stage 사이에 불필요한 tail latency가 생깁니다.

## Pipeline idea

본 프로젝트에서는 ready window 단위로 producer-consumer execution을 중첩하는 **sliding-window pipeline**을 사용합니다.

```text
DWC produces valid window
        ↓
small/local buffer
        ↓
PWC consumes available data
```

전체 feature map completion을 기다리지 않고 다음 stage를 시작해 pipeline idle time을 줄이는 것이 목적입니다.

## Public result

구현 결과는 다음과 같습니다.

- frame rate: **252.7 FPS**
- throughput: **287.6 GOPS**
- power efficiency: **66.9 GOPS/W**
- hardware efficiency: **3.34 GOPS/DSP**

## Disclosure boundary

정확한 internal timing diagram과 proposed coupling structure는 manuscript용 자료이므로 공개하지 않습니다.
