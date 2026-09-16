# Local Memory and Banking

## Why memory matters

MobileNetV1은 FLOPs가 작더라도 feature map과 local data를 반복해서 큰 memory에서 읽으면 energy와 bandwidth cost가 커집니다.

따라서 본 프로젝트에서는 compute array만이 아니라 **local reuse와 memory banking**을 함께 설계했습니다.

## Public design principles

- frequently reused activation을 local buffer에서 재사용
- DWC/PWC data supply를 compute와 분리
- banking을 통해 필요한 read bandwidth 확보
- BRAM/LUTRAM 사용과 routing cost를 함께 고려
- layer별 feature-map 크기 변화에 맞춰 buffer behavior 조정

## Evidence boundary

논문용 line-buffer figure와 상세 memory hierarchy는 공개하지 않습니다.  
이 문서에서는 실제 구현에서 사용한 **설계 원칙과 trade-off**만 설명합니다.
