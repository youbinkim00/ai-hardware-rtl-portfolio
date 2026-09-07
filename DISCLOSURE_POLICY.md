# Disclosure Policy

## Public

- 프로젝트 목적과 external system boundary
- 검증 방법과 acceptance criteria
- Sanitized AXI VIP/DMA Block Design
- Annotated protocol waveform
- 요약된 기능·timing·resource 결과
- 일반화한 FPGA engineering note와 독립 예제

## Private until publication review

- 전체 SystemVerilog RTL
- PE/requantization microarchitecture
- Multi-layer scheduling 및 dataflow selection rule
- Detailed memory banking/address generation
- Layer/state mapping과 prefetch schedule
- QAT notebook, checkpoint, weight와 parameter payload
- Golden vector와 dataset image
- Vivado project/generated output, `.bit`, `.hwh`, `.dcp`
- 논문용 Top Architecture 및 novelty figure
- 미확정 power-ablation 결과

## Release gate

Public 전환 전에 다음을 점검합니다.

- 경로와 사용자 정보 제거
- 논문 novelty 노출 여부 확인
- Xilinx generated IP 또는 재배포 제한 파일 미포함
- Dataset/third-party license 확인
- Pending 결과를 완료 결과처럼 표현하지 않음
- 수치의 출처와 검증 상태 기록

