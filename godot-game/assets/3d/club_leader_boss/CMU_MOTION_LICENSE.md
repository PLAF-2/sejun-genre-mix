# CMU 보행 모션 출처 및 사용 조건

사용 파일: Carnegie Mellon University Graphics Lab Motion Capture Database, subject 07, motion 07_01.
- 공식 데이터: https://mocap.cs.cmu.edu/subjects/07/07.asf
- 공식 데이터: https://mocap.cs.cmu.edu/subjects/07/07_01.amc
- 공식 사용 조건: https://mocap.cs.cmu.edu/
- 단위 변환/촬영 정보: https://mocap.cs.cmu.edu/faqs.php

확인일: 2026-10-28. 공식 페이지는 모든 용도에 무료로 이용 가능한 자료라고 안내하며 상용 제품에 포함하는 것을 허용한다. 모션 데이터 자체를 변환 형식까지 포함하여 직접 재판매하는 것은 허용하지 않는다. 이 프로젝트는 데이터를 게임 캐릭터에 맞춰 변환하여 게임의 일부로 사용하며 모션 자료를 상품으로 재판매하지 않는다.

Acknowledgment:
The data used in this project was obtained from mocap.cs.cmu.edu.
The database was created with funding from NSF EIA-0196217.

원본 자료는 프로젝트 루트 blender_project/motion_sources/cmu_07/에 보관한다. prepare_cmu_walk.py가 ASF/AMC를 읽어 실제 골격 관절 궤적을 계산하고 54~185 프레임(120Hz)의 한 보행 주기를 추출한다. 약한 평활화·루프 연결·발 접지 보정을 거쳐 refine_boss_walk_v4.py에서 새 신체 비율의 기존 골격으로 리타게팅한다. 원본 촬영 인물의 신원이나 모습은 캐릭터에 사용하지 않으며 얼굴은 기존에 제공된 동아리장 사진 기반 텍스처를 유지한다.
