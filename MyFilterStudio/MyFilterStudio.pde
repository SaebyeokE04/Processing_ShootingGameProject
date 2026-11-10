import processing.video.*;
import java.io.File;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

// 나만의 필터 스튜디오 — Processing 4 / Java mode
ArrayList<Photo> photos = new ArrayList<Photo>();
ArrayList<Integer> picks = new ArrayList<Integer>();
String[] filterNames = {"원본", "흑백", "세피아", "필름", "픽셀아트", "만화풍"};
int selected = -1, listOffset = 0, collageMode = 0, bgIndex = 0;
int[] paper = {0xfff4f0e8, 0xff171a22, 0xffe9cbd6, 0xffbcd8d5};
float margin = 32, uiScale = 1, ox, oy, mx, my;
boolean live = false, compare = false, cropping = false, draggingCrop = false;
boolean dirty = true, dialogOpen = false;
float cropAX, cropAY, cropBX, cropBY;
int ratioIndex = 0;
String[] ratioNames = {"자유", "1:1", "4:3", "16:9", "3:4"};
float[] ratios = {0, 1, 4.0f/3, 16.0f/9, 3.0f/4};
CameraTask cameraTask;
String[] devices = new String[0];
int deviceIndex = 0;
PImage rawFrame, preview;
Edit cameraEdit = new Edit();
volatile File inputChoice, outputChoice;
volatile boolean inputDone = false, outputDone = false;
String message = "사진을 불러오거나 웹캠을 켜서 시작하세요.";
ArrayList<Button> buttons = new ArrayList<Button>();
ArrayList<Slider> sliders = new ArrayList<Slider>();
Slider activeSlider;
float imageX, imageY, imageW, imageH;

void settings() { size(1100, 825); }
void setup() {
  surface.setTitle("나만의 필터 스튜디오 | My Filter Studio");
  surface.setResizable(true);
  String fontName = "SansSerif";
  String[] fonts = PFont.list();
  String[] preferred = {"Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "NanumGothic", "Dialog"};
  outer: for (String candidate : preferred) for (String f : fonts) if (f.equals(candidate)) { fontName = f; break outer; }
  textFont(createFont(fontName, 14, true));
  frameRate(30);
}

void draw() {
  handleFiles();
  pollCamera();
  if (dirty) refreshPreview();
  background(13, 16, 23);
  uiScale = min(width/1200.0f, height/900.0f);
  ox = (width-1200*uiScale)/2; oy = (height-900*uiScale)/2;
  mx = (mouseX-ox)/uiScale; my = (mouseY-oy)/uiScale;
  pushMatrix(); translate(ox, oy); scale(uiScale);
  buttons.clear(); sliders.clear();
  noStroke(); fill(23, 28, 39); rect(0, 0, 1200, 80);
  fill(239); textSize(22); text("나만의 필터 스튜디오", 22, 31);
  fill(141, 155, 177); textSize(12); text("MY FILTER STUDIO  /  JAVA EDITION", 23, 55);
  button("import", "사진 불러오기", 330, 21, 126, 38, false, !dialogOpen);
  button("camera", live?(rawFrame==null?"연결 취소":"웹캠 끄기"):"웹캠 켜기", 466, 21, 116, 38, live, !dialogOpen);
  button("capture", "촬영", 592, 21, 76, 38, false, live && rawFrame!=null);
  button("savepng", "PNG 저장", 954, 21, 106, 38, false, preview!=null && !live && !dialogOpen);
  button("savejpg", "JPG 저장", 1070, 21, 106, 38, false, preview!=null && !live && !dialogOpen);
  fill(20, 24, 34); rect(14, 96, 190, 720, 12); rect(900, 96, 286, 720, 12);
  fill(218); textSize(15); text("사진 보관함  "+photos.size(), 28, 122);
  fill(145, 157, 177); textSize(11); text("왼쪽 작은 칸: 네 컷 선택 (최대 4)", 26, 144);
  drawPhotoList();
  button("prev", "▲", 26, 772, 78, 28, false, listOffset>0);
  button("next", "▼", 112, 772, 78, 28, false, listOffset+5<photos.size());
  fill(155, 169, 189); textSize(13);
  String title = live ? "LIVE  ·  "+(rawFrame==null?"카메라 연결 중":"실시간 미리보기") : collageMode>0?"네 컷 합성 미리보기" : selected>=0?photos.get(selected).name:"PHOTO PREVIEW";
  if(title.length()>50)title=title.substring(0,48)+"…";
  text(title, 224, 120);
  fill(10, 13, 19); rect(220, 138, 662, 570, 10);
  PImage shown = preview;
  if (compare && !live && collageMode==0 && selected>=0) shown = photos.get(selected).thumb;
  imageW=imageH=0;
  if (shown!=null) {
    float s = min(638.0f/shown.width, 546.0f/shown.height);
    imageW=shown.width*s; imageH=shown.height*s;
    imageX=551-imageW/2; imageY=423-imageH/2;
    image(shown, imageX, imageY, imageW, imageH);
    if (draggingCrop) drawCropBox();
  } else { fill(126, 140, 164); textAlign(CENTER); textSize(18); text("사진 불러오기 또는 웹캠 켜기", 551, 407); textSize(12); text("JPG / PNG · 원본을 보존하는 편집", 551, 435); textAlign(LEFT); }
  button("compare", compare?"원본 보는 중":"원본 비교", 224, 724, 118, 34, compare, selected>=0 && !live && collageMode==0 && !cropping);
  button("back", "사진 편집으로", 352, 724, 124, 34, false, collageMode>0);
  fill(142, 159, 180); textSize(12); text(cropping?"미리보기에서 드래그 → 자르기 적용. 비율은 오른쪽에서 선택합니다.":"미리보기는 축소 처리 · 저장은 원본 해상도 재처리", 224, 786);
  drawTools();
  fill(23, 28, 39); rect(14, 830, 1172, 54, 10);
  fill(190, 216, 222); textSize(13); text(message, 28, 851, 1142, 30);
  popMatrix();
}

Edit currentEdit() { return live ? cameraEdit : selected>=0 ? photos.get(selected).edit : cameraEdit; }
boolean editable() { return live || selected>=0; }
void changed() { dirty=true; compare=false; collageMode=0; }

void refreshPreview() {
  dirty=false;
  try {
    if (collageMode>0) preview=makeCollage(false);
    else if (live) preview=rawFrame==null?null:renderImage(rawFrame, cameraEdit, 800, false);
    else preview=selected<0?null:renderImage(photos.get(selected).original, currentEdit(), 1000, cropping);
  } catch (Exception ex) { message="미리보기 실패: "+ex.getMessage(); }
}

void drawPhotoList() {
  for (int row=0; row<5; row++) {
    int i=listOffset+row; if(i>=photos.size()) break;
    Photo p=photos.get(i); float y=158+row*120;
    fill(i==selected && !live?color(43, 78, 87):color(31, 37, 50)); rect(24,y,170,112,8);
    float s=min(124.0f/p.thumb.width,76.0f/p.thumb.height);
    image(p.thumb,110-p.thumb.width*s/2,y+7,p.thumb.width*s,p.thumb.height*s);
    fill(picks.contains(i)?color(72,205,178):color(68,77,94)); rect(29,y+10,20,20,4);
    if(picks.contains(i)) { fill(12,30,34); textSize(12); text(""+(picks.indexOf(i)+1),35,y+25); }
    fill(219); textSize(11); String n=p.name; if(n.length()>21)n=n.substring(0,19)+"…"; text(n,31,y+101);
  }
}

void drawTools() {
  Edit e=currentEdit(); boolean ok=editable() && collageMode==0;
  fill(224); textSize(15); text("필터 & 세부 편집", 918, 124);
  for(int i=0;i<6;i++) button("f"+i,filterNames[i],918+(i%2)*130,140+(i/2)*38,122,32,e.filter==i,ok);
  slider("brightness","밝기",e.brightness,-100,100,265,ok);
  slider("contrast","대비",e.contrast,0.2f,2.5f,318,ok);
  slider("saturation","채도",e.saturation,0,2,371,ok);
  slider("strength","필터 강도",e.strength,0,1,424,ok);
  slider("pixel","픽셀 크기 (% 폭)",e.pixel,0.3f,5,477,ok);
  button("flip","좌우 반전",918,526,122,30,e.flip,ok && !cropping);
  button("rotate","90° 회전",1048,526,122,30,false,ok && !cropping);
  button("crop","자르기 영역",918,564,122,30,cropping,ok && !live);
  button("ratio",ratioNames[ratioIndex],1048,564,122,30,false,cropping);
  button("applycrop","자르기 적용",918,602,122,30,false,cropping && draggingCrop);
  button("cancelcrop","취소",1048,602,122,30,false,cropping);
  button("reset","현재 사진 초기화",918,640,252,30,false,ok);
  fill(177); textSize(12); text("네 컷 · 선택 "+picks.size()+" / 4",918,696);
  button("collage1","한 장 × 4필터",918,706,122,30,collageMode==1,selected>=0 && !live);
  button("collage4","선택한 네 장",1048,706,122,30,collageMode==2,picks.size()==4 && !live);
  button("margin","여백: "+(int)margin,918,744,122,28,false,collageMode>0);
  button("paper","배경색 변경",1048,744,122,28,false,collageMode>0);
  button("device","카메라 선택 "+(devices.length==0?"(검색 전)":(deviceIndex+1)+"/"+devices.length),918,780,252,26,false,!live);
}

void mousePressed() {
  for(Button b:buttons) if(b.enabled && b.hit(mx,my)) { action(b.id); return; }
  for(Slider s:sliders) if(s.enabled && s.hit(mx,my)) { activeSlider=s; setSlider(s); return; }
  if(mx>=24 && mx<194 && my>=158 && my<758) {
    int row=(int)((my-158)/120), i=listOffset+row;
    if(i<photos.size()) {
      if(mx<52) { if(picks.contains(i))picks.remove((Integer)i); else if(picks.size()<4)picks.add(i); else message="네 장까지 선택할 수 있습니다."; if(collageMode==2){if(picks.size()!=4)collageMode=0;dirty=true;} }
      else { stopCamera(); selected=i; cropping=draggingCrop=false; changed(); }
    } return;
  }
  if(cropping && imageW>0 && mx>=imageX && mx<=imageX+imageW && my>=imageY && my<=imageY+imageH) {
    cropAX=(mx-imageX)/imageW; cropAY=(my-imageY)/imageH;
    cropBX=cropAX; cropBY=cropAY; draggingCrop=true;
  }
}
void mouseDragged() {
  mx=(mouseX-ox)/uiScale; my=(mouseY-oy)/uiScale;
  if(activeSlider!=null) setSlider(activeSlider);
  else if(cropping && draggingCrop) {
    cropBX=constrain((mx-imageX)/imageW,0,1); cropBY=constrain((my-imageY)/imageH,0,1);
    float ratio=ratios[ratioIndex];
    if(ratio>0) {
      float dx=cropBX-cropAX, dy=cropBY-cropAY;
      float w=abs(dx), h=abs(dy), nr=ratio*imageH/imageW;
      w=min(w,h*nr); h=w/nr;
      cropBX=cropAX+(dx<0?-w:w); cropBY=cropAY+(dy<0?-h:h);
    }
  }
}
void mouseReleased() { activeSlider=null; }
void mouseWheel(processing.event.MouseEvent event) {
  if(mx<204)listOffset=constrain(listOffset+(int)event.getCount(),0,max(0,photos.size()-5));
}

void action(String id) {
  if(id.equals("import")) { dialogOpen=true; selectInput("JPG 또는 PNG 사진 선택", "photoChosen"); }
  else if(id.equals("camera")) { if(live){stopCamera();changed();}else startCamera(); }
  else if(id.equals("capture")) {
    Photo p=new Photo(rawFrame.get(),"촬영 "+(photos.size()+1)); p.edit=cameraEdit.copy();
    photos.add(p); selected=photos.size()-1; listOffset=max(0,selected-4); stopCamera(); changed(); message="촬영한 원본 프레임과 편집 설정을 사진 목록에 추가했습니다.";
  }
  else if(id.startsWith("save")) beginSave(id.equals("savejpg"));
  else if(id.length()==2 && id.charAt(0)=='f') { currentEdit().filter=id.charAt(1)-'0'; changed(); }
  else if(id.equals("flip")) { currentEdit().flip=!currentEdit().flip; currentEdit().clearCrop(); changed(); }
  else if(id.equals("rotate")) { currentEdit().turns=(currentEdit().turns+1)%4; currentEdit().clearCrop(); changed(); }
  else if(id.equals("reset")) { if(live)cameraEdit=new Edit();else photos.get(selected).edit=new Edit(); cropping=draggingCrop=false;changed(); }
  else if(id.equals("compare"))compare=!compare;
  else if(id.equals("crop")) { cropping=!cropping; draggingCrop=false; compare=false;dirty=true; }
  else if(id.equals("ratio")) {ratioIndex=(ratioIndex+1)%ratios.length;draggingCrop=false;}
  else if(id.equals("cancelcrop")) {cropping=draggingCrop=false;dirty=true;}
  else if(id.equals("applycrop")) {
    if(abs(cropBX-cropAX)*imageW<5 || abs(cropBY-cropAY)*imageH<5) {message="자르기 영역이 너무 작습니다. 다시 드래그하세요.";return;}
    Edit e=currentEdit();e.cx=min(cropAX,cropBX);e.cy=min(cropAY,cropBY);e.cw=abs(cropBX-cropAX);e.ch=abs(cropBY-cropAY);
    cropping=draggingCrop=false;changed();
  }
  else if(id.equals("prev"))listOffset=max(0,listOffset-5);
  else if(id.equals("next"))listOffset=min(max(0,photos.size()-5),listOffset+5);
  else if(id.equals("back"))changed();
  else if(id.equals("collage1") || id.equals("collage4")) {collageMode=id.equals("collage1")?1:2;cropping=draggingCrop=compare=false;dirty=true;}
  else if(id.equals("margin")) {margin=margin>=80?0:margin+16;dirty=true;}
  else if(id.equals("paper")) {bgIndex=(bgIndex+1)%paper.length;dirty=true;}
  else if(id.equals("device")) {
    if(devices.length>0){deviceIndex=(deviceIndex+1)%devices.length;message="카메라: "+devices[deviceIndex];}
    else beginCameraTask(true);
  }
}

void drawCropBox() {
  noFill(); stroke(80,236,196); strokeWeight(2);
  rect(imageX+min(cropAX,cropBX)*imageW,imageY+min(cropAY,cropBY)*imageH,abs(cropBX-cropAX)*imageW,abs(cropBY-cropAY)*imageH);
  noStroke();
}
