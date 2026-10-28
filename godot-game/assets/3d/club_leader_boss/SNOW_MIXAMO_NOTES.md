# Snow 의상 및 Mixamo 보행 적용

현재 게임 모델: `club_leader_boss_mixamo_v7.glb`
현재 Blender 원본: 프로젝트 루트 `blender_project/club_leader_boss/club_leader_boss_mixamo_v7.blend`

## Snow 의상 — CC BY 4.0
출처: https://studio.blender.org/characters/snow/v2/
라이선스: https://creativecommons.org/licenses/by/4.0/
필수 출처 표시: Snow Rig © Blender Foundation | studio.blender.org

Blender Studio의 Snow v2에서 별도 제작된 티셔츠와 바지 메시, diffuse/normal/roughness 텍스처를 사용했다. 원본 Snow 의상은 T자 자세이며 기존 보스의 A자 자세와 길어진 체형에 맞춰 형태를 조정했다. 원래 DEF 관절 가중치를 기존 골격의 대응 관절 이름으로 옮겨 스킨을 연결했다. 원본 의상의 shape key는 고정한 뒤 조정했고, 원본 자체는 보존했다. 텍스처는 게임용으로 2K로 줄여 GLB에 내장했다. 얼굴·머리카락·손·신발은 기존 사진 기반 모델을 유지하고, 드러난 팔/목 부분은 기존 인체를 사용했다.

코드: `blender_tools/adapt_snow_clothes_v6.py`
원본: `blender_project/third_party/snow/source/snow_v02.blend`
다운로드 원본은 크기가 커 공개 업로드에서 제외하고, 수정한 게임 모델과 출처 표시는 포함한다. Snow의 스크립트를 자동 실행하지 않고 메시·텍스처·가중치만 활용했다.

## Adobe Mixamo — Walking
출처: https://www.mixamo.com/
공식 안내: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html

사용자가 직접 Adobe에 로그인한 후 애니메이션 라이브러리에서 Walking(설명: Walking With A Swagger)을 선택했다. X Bot 기준 FBX Binary, Without Skin, 30fps, Keyframe Reduction none으로 다운로드했다. 사용자 사진이나 보스 모델을 Mixamo에 업로드하지 않았다. 내려받은 관절 궤적을 로컬에서 기존 보스의 길이에 맞춰 리타게팅하고 전진 주기만 기존 Boss_Walk 클립으로 베이크했다. 기존 대기/시전/돌진 및 사망 처리는 유지한다.

원본 FBX: `blender_project/motion_sources/mixamo/Walking.fbx` — 공개 저장소에서 제외.
처리: `blender_tools/prepare_mixamo_walk.py` → `retarget_mixamo_v7.py`
게임 공간 속도 5.566m/s를 기준으로 실제 이동 속도에 맞춰 재생한다. 모션은 게임 캐릭터에 통합해 사용하며 원본 Mixamo 모션 파일을 별도 에셋으로 재배포하지 않는다. 엔딩 크레딧에도 제작 출처를 표시한다.

이번 단계에서는 새 이미지 생성 도구를 사용하지 않았다. 기존 얼굴 이미지의 제작 기록은 REBUILT_ASSET_NOTES.md를 참고한다. 모델의 바탕을 개선했지만 첨부한 상용 캐릭터와 동등한 최종 완성도를 보장하는 결과로 취급하지 않는다.
