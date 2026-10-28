# 이상민 보스 캐릭터 재제작 v2

## 게임에 적용한 파일
- `club_leader_boss_rebuilt_v2.glb`: 최종 결투에서 사용하는 실제 골격/스킨이 있는 3D 모델.
- `boss_skin_albedo_v2.png`: 얼굴·귀·목·손을 위한 2048×2048 UV 텍스처. GLB에도 내장한다.
- `face_albedo_reference_v2.png`: 내장 image_gen으로 제작한 사진 기반 얼굴 텍스처 참고 이미지. 원본 참고 사진은 `references/`에서 계속 비공개로 보관한다.
- Blender 원본: 프로젝트 루트 `blender_project/club_leader_boss/club_leader_boss_rebuilt_v2.blend`.
- 제작 스크립트: 프로젝트 루트 `blender_tools/rebuild_boss_character.py`. 보존한 polished 원본을 열고 실행한다.

## 제작 방식과 범위
추가 사진 없이 기존에 제공한 두 사진 속 남자를 참고했다. 인체와 기존 전투 골격은 보존하며 기존 모델의 표면·의상·헤어·눈을 재제작했다. 재킷/바지/신발은 기존 인체에서 연속된 표면을 추출하고 옷 여유와 봉제 디테일을 추가했다. 머리카락은 캡과 단면이 납작한 23개 입체 머리 묶음이다. 얼굴 이미지는 기존 얼굴 표면 UV로 베이크했으며 평면 얼굴 판/빌보드는 사용하지 않는다. 원본·구버전 GLB는 보존했다. 2D 카드/대화 캐릭터는 이번 3D 재제작 범위에서 변경하지 않는다.

전투/이동/시전/사망 동작은 Godot의 기존 골격 제어를 사용한다. 외부 상용 게임의 모델이나 텍스처를 복제하지 않았다. 현재 결과는 자체 제작 게임용 개선 모델이며 상용 AAA 게임과 동일한 완성도를 보장하지 않는다.

## imagegen 기록
내장 image_gen 도구를 사용했다. reference image는 기존 제공한 남자의 정면/측면 사진이다. 결과를 프로젝트로 복사하고 3D 텍스처에 적용했다. 최종 프롬프트:

Create a production texture reference for an original stylized 3D game character based on the adult Korean MAN in the reference photos, preserving his recognizable face proportions, narrow almond dark eyes, straight dark eyebrows, defined natural nose, slim oval face and black hair. NOT the woman. Output ONE perfectly frontal orthographic head only, centered, symmetrical neutral relaxed expression, looking straight ahead, from top of scalp to just below chin. Face fills image: crown at 4% image height, chin at 94%, ears approximately x=10% and 90%. High quality contemporary stylized tactical hero aesthetic, sophisticated hand-painted diffuse/albedo suitable for a 3D game skin texture, clean subtle skin color gradients and natural pink lips, subtle under-eye and nose definition. FLAT SOFT SHADOWLESS LIGHTING, no dramatic cast shadows, no specular highlights, no rim light, no ambient occlusion. Keep scalp hair DARK but pulled up away from entire forehead so brow/forehead visible (actual 3D hair is modeled separately). Light warm neutral grey background. Eyes naturally open, realistic small iris, no oversized anime eyes. No clothes, no shoulders, no text, no objects, no accessories, no facial hair. This is a TEXTURE REFERENCE to project onto genuine 3D face geometry, not a finished game screenshot. Crisp facial features with painterly restrained style, not clay, plastic or wax.
