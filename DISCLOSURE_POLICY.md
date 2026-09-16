# Disclosure Policy

이 저장소는 채용 검토와 기술 포트폴리오를 위한 공개 문서이다. 기업 영업비밀과 제3자 비공개 자료는 포함하지 않는다.

## Public

- 프로젝트 목적과 외부 system boundary
- 설계 방법론의 공개 가능한 상위 원칙
- 검증 절차, acceptance criteria와 요약 결과
- Sanitized AXI VIP/DMA 연결 구조와 protocol 설명
- 출처와 검증 상태가 명시된 정확도·자원·timing 결과
- 범용적인 FPGA/RTL engineering note

## Private until publication review

- 전체 SystemVerilog RTL과 testbench
- PE/requantization microarchitecture
- Multi-layer scheduling 선택 규칙과 layer-state mapping
- 상세 memory banking, address generation과 prefetch schedule
- QAT notebook, checkpoint, trained weights와 parameter payload
- Golden vector와 dataset image
- Vivado project/generated output, `.bit`, `.hwh`, `.dcp`
- 논문용 Top Architecture와 novelty figure
- MobileNetV1 manuscript의 proposed architecture, adaptive-parallelism, line-buffer, memory-hierarchy와 pipeline-timing novelty figure
- 재현 조건이 고정되지 않은 power/board benchmark

## Release gate

공개 전 다음을 확인한다.

- 사용자 이름 이외의 개인정보와 로컬 경로 제거
- 논문 novelty와 비공개 core 정보 노출 여부 확인
- AMD/Xilinx generated IP 및 라이선스 제한 파일 미포함
- Dataset/third-party asset license와 attribution 확인
- Pending 결과를 완료 결과처럼 표현하지 않음
- 모든 수치에 platform, configuration, source와 검증 상태 기록
- 기업 기밀 또는 제3자 영업비밀이 없음을 재확인
