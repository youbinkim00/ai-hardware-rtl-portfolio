# MobileNet RTL Accelerator

> Status: planned; project evidence has not yet been migrated into this portfolio.

이 영역은 MobileNet 계열 workload에 대한 독립 RTL 프로젝트를 정리하기 위한 자리입니다. 현재 단계에서는 YOLOv5s 프로젝트의 방법론이나 수치를 복사해 일반화하지 않습니다.

추후 실제 source, verification artifact와 implementation report를 점검한 뒤 다음 내용을 채웁니다.

- Target MobileNet version, dataset와 accuracy baseline
- Depthwise/pointwise convolution의 workload 특성
- Software–RTL numeric contract
- Compute/memory architecture와 scheduling
- Module/full-network verification
- Post-route PPA와 deployment status
- YOLOv5s 사례와 공통인 방법론 및 workload-specific 차이

완료된 증거가 생기기 전에는 성능·전력·일반화 claim을 작성하지 않습니다.
