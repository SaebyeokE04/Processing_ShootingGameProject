boolean saveJpg=false;
PImage pendingSave;
void photoChosen(File f){inputChoice=f;inputDone=true;}
void saveChosen(File f){outputChoice=f;outputDone=true;}
void handleFiles(){
  if(inputDone){
    inputDone=false;dialogOpen=false;File f=inputChoice;
    if(f==null){message="사진 선택을 취소했습니다.";}
    else try {
      String n=f.getName().toLowerCase(java.util.Locale.ROOT);
      if(!n.endsWith(".jpg")&&!n.endsWith(".jpeg")&&!n.endsWith(".png"))throw new Exception("JPG 또는 PNG 파일을 선택하세요.");
      PImage img=loadImage(f.getAbsolutePath());
      if(img==null||img.width<=0||img.height<=0)throw new Exception("이미지를 읽을 수 없습니다.");
      photos.add(new Photo(img,f.getName()));selected=photos.size()-1;listOffset=max(0,selected-4);
      stopCamera();cropping=draggingCrop=false;changed();message="추가됨: "+f.getName()+" ("+img.width+" × "+img.height+")";
    }catch(Exception ex){message="불러오기 실패: "+ex.getMessage();}
    catch(OutOfMemoryError ex){message="메모리가 부족합니다. 사진 크기나 개수를 줄여 주세요.";}
  }
  if(outputDone){
    outputDone=false;dialogOpen=false;File f=outputChoice;
    if(f==null){pendingSave=null;message="저장을 취소했습니다.";return;}
    try {
      String path=f.getAbsolutePath(), low=path.toLowerCase(java.util.Locale.ROOT);
      String ext=saveJpg?"jpg":"png";
      if(!low.endsWith("."+ext) && !(saveJpg&&low.endsWith(".jpeg"))) {
        // 다른 확장자를 입력해도 실제 인코딩과 확장자가 다르지 않게 교체한다.
        if(low.endsWith(".png")||low.endsWith(".jpg")||low.endsWith(".jpeg"))path=path.substring(0,path.lastIndexOf('.'));
        path+="."+ext;
      }
      File target=new File(path);
      // 확장자 보정 후 생긴 경로도 덮어쓰기 확인에 포함한다.
      if(target.exists()){
        int answer=javax.swing.JOptionPane.showConfirmDialog(null,"기존 파일을 덮어쓸까요?\n"+path,"저장 확인",javax.swing.JOptionPane.YES_NO_OPTION);
        if(answer!=javax.swing.JOptionPane.YES_OPTION){message="덮어쓰기를 취소했습니다.";pendingSave=null;return;}
      }
      writeResult(pendingSave,target,saveJpg);message="저장 완료: "+path;
    }catch(Exception ex){message="저장 실패: "+ex.getMessage();}
    finally{pendingSave=null;}
  }
}
void beginSave(boolean jpg){
  if(selected<0)return;
  try{
    // 대화상자를 열기 전에 결과를 확정해서 사진/설정 변경에 영향받지 않는다.
    pendingSave=collageMode>0?makeCollage(true):renderImage(photos.get(selected).original,currentEdit(),0,false);
    saveJpg=jpg;dialogOpen=true;
    selectOutput("결과 이미지 저장 위치", "saveChosen",new File(sketchPath("studio_result."+(jpg?"jpg":"png"))));
  }catch(Exception ex){dialogOpen=false;message="저장 준비 실패: "+ex.getMessage();}
  catch(OutOfMemoryError ex){dialogOpen=false;pendingSave=null;message="저장 메모리가 부족합니다. 다른 앱을 닫거나 사진 크기를 줄여 주세요.";}
}
void writeResult(PImage img,File target,boolean jpg) throws Exception {
  img.loadPixels();BufferedImage out=new BufferedImage(img.width,img.height,jpg?BufferedImage.TYPE_INT_RGB:BufferedImage.TYPE_INT_ARGB);
  for(int y=0;y<img.height;y++)for(int x=0;x<img.width;x++){
    int c=img.pixels[y*img.width+x];
    if(jpg){float a=((c>>>24)&255)/255.0f;c=0xff000000|(round(lerp(255,(c>>16)&255,a))<<16)|(round(lerp(255,(c>>8)&255,a))<<8)|round(lerp(255,c&255,a));}
    out.setRGB(x,y,c);
  }
  File tmp=File.createTempFile("studio-", ".tmp",target.getAbsoluteFile().getParentFile());
  try{
    if(!ImageIO.write(out,jpg?"jpg":"png",tmp))throw new Exception("이미지 인코더를 찾을 수 없습니다.");
    Files.move(tmp.toPath(),target.toPath(),StandardCopyOption.REPLACE_EXISTING);
  }finally{if(tmp.exists())tmp.delete();}
}
void startCamera(){
  beginCameraTask(false);
}
void beginCameraTask(boolean listOnly){
  // 네이티브 호출이 걸려 있는 동안 새 스레드를 계속 만들지 않는다.
  if(cameraTask!=null && cameraTask.worker!=null && cameraTask.worker.isAlive()){
    message="이전 카메라 작업이 아직 응답하지 않습니다. 사진 편집은 가능하며, 재연결은 앱 재실행 후 시도하세요.";return;
  }
  stopCamera();
  if(!listOnly){cropping=draggingCrop=false;collageMode=0;compare=false;live=true;preview=null;}
  cameraTask=new CameraTask(listOnly,devices.clone(),deviceIndex);
  cameraTask.worker=new Thread(cameraTask,"Studio-camera");
  cameraTask.worker.setDaemon(true); // 응답 없는 드라이버 때문에 작업 스레드가 앱 종료를 막지 않도록 한다.
  dirty=true;message=listOnly?"카메라 목록 검색 중…":"카메라 연결 중… (최대 10초, 연결 취소 가능)";
  cameraTask.worker.start();
}
void pollCamera(){
  CameraTask task=cameraTask;
  if(task==null || !task.active)return;
  if(task.found!=null){devices=task.found;deviceIndex=constrain(deviceIndex,0,max(0,devices.length-1));}
  if(task.latest!=null && task.latest!=rawFrame && live){rawFrame=task.latest;dirty=true;}
  if(task.failure!=null){
    String error=task.failure;stopCamera();dirty=true;
    message="웹캠 실패: "+error+" 사진 불러오기는 계속 사용할 수 있습니다.";return;
  }
  if(task.listOnly && task.done){
    task.active=false;message=devices.length==0?"연결된 카메라가 없습니다.":"카메라: "+devices[deviceIndex];return;
  }
  if(System.nanoTime()-task.lastActivity>10000000000L){
    String stage=task.stage;stopCamera();dirty=true;
    message="웹캠 시간 초과 ("+stage+"). 카메라 권한/다른 앱 점유를 확인하세요. 사진 편집은 가능합니다.";
  }
}
void stopCamera(){
  live=false;rawFrame=null;
  // draw()에서 stop/dispose를 호출하면 종료 시에도 화면이 멈출 수 있다.
  // 플래그만 전달하고 Capture 생성·읽기·해제는 모두 같은 작업 스레드가 맡는다.
  if(cameraTask!=null)cameraTask.active=false;
}

class CameraTask implements Runnable {
  final boolean listOnly;
  final String[] knownDevices;
  final int choice;
  volatile boolean active=true,done=false;
  volatile String[] found;
  volatile String failure,stage="장치 검색";
  volatile PImage latest;
  volatile long lastActivity=System.nanoTime();
  Thread worker;
  CameraTask(boolean only,String[] names,int index){listOnly=only;knownDevices=names;choice=index;}
  public void run(){
    Capture capture=null;
    try{
      found=knownDevices.length>0 && !listOnly?knownDevices:Capture.list();
      if(!active)return;
      if(found.length==0){failure="카메라를 찾지 못했습니다.";return;}
      if(listOnly)return;
      stage="장치 열기";
      capture=new Capture(MyFilterStudio.this,found[constrain(choice,0,found.length-1)]);
      if(!active)return;
      stage="캡처 시작";capture.start();
      while(active){
        stage="프레임 대기";
        if(capture.available()){
          stage="프레임 읽기";capture.read();
          if(capture.width>0 && capture.height>0){
            // get()으로 독립 복사한 프레임만 전달하여 읽기와 필터 처리의 충돌을 막는다.
            latest=capture.get();lastActivity=System.nanoTime();
          }
        }
        Thread.sleep(12);
      }
    }catch(Throwable ex){
      println("[웹캠] "+stage+": "+ex);ex.printStackTrace();
      failure=stage+" / "+ex.getClass().getSimpleName();
    }finally{
      if(capture!=null){
        try{capture.stop();}catch(Throwable ex){println("[웹캠 종료] "+ex);}
        try{capture.dispose();}catch(Throwable ex){println("[웹캠 해제] "+ex);}
      }
      done=true;
    }
  }
}
void exit(){stopCamera();super.exit();}
