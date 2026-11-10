// 출력 좌표를 원본 좌표로 역변환한다. 원본 pixels[]는 절대로 수정하지 않는다.
// 자르기는 회전/반전 이후의 화면에 대한 0~1 정규화 좌표로 저장한다.
PImage renderImage(PImage src, Edit e, int limit, boolean uncropped) {
  src.loadPixels();
  int ow=e.turns%2==0?src.width:src.height, oh=e.turns%2==0?src.height:src.width;
  float cx=uncropped?0:e.cx, cy=uncropped?0:e.cy, cw=uncropped?1:e.cw, ch=uncropped?1:e.ch;
  int fullW=max(1,round(ow*cw)), fullH=max(1,round(oh*ch));
  float scale=limit<=0?1:min(1,limit/(float)max(fullW,fullH));
  int w=max(1,round(fullW*scale)),h=max(1,round(fullH*scale));
  PImage out=createImage(w,h,ARGB);out.loadPixels();
  for(int y=0;y<h;y++)for(int x=0;x<w;x++){
    float u=cx+(x+0.5f)/w*cw, v=cy+(y+0.5f)/h*ch;
    int base=sample(src,e,u,v);
    float br=(base>>16)&255,bg=(base>>8)&255,bb=base&255;
    float r=br,g=bg,b=bb;
    if(e.filter==1){r=g=b=luma(base);}
    if(e.filter==2){r=br*0.393f+bg*0.769f+bb*0.189f;g=br*0.349f+bg*0.686f+bb*0.168f;b=br*0.272f+bg*0.534f+bb*0.131f;}
    if(e.filter==3){
      // 위치 해시: 프레임마다 random()을 쓰지 않아 저장과 미리보기의 입자 패턴이 같다.
      int nx=(int)(u*ow+0.001f), ny=(int)(v*oh+0.001f);
      int hash=nx*374761393+ny*668265263+e.seed; hash=(hash^(hash>>>13))*1274126177;hash^=hash>>>16;
      float grain=((hash&65535)/65535.0f-0.5f)*22;
      float dx=(u-0.5f)*2,dy=(v-0.5f)*2;
      float vignette=1-0.30f*constrain((dx*dx+dy*dy)/2,0,1);
      r=(br*1.08f+9+grain)*vignette;g=(bg*1.01f+3+grain)*vignette;b=(bb*0.9f+grain)*vignette;
    }
    if(e.filter==4){
      // 블록 중심을 샘플링하고 채널을 6단계로 양자화한다. 픽셀 크기는 원본 폭에 대한 비율.
      float step=e.pixel/100, stepY=step*ow/oh;
      int c=sample(src,e,(floor(u/step)+0.5f)*step,(floor(v/stepY)+0.5f)*stepY);
      r=quant((c>>16)&255,6);g=quant((c>>8)&255,6);b=quant(c&255,6);
    }
    if(e.filter==5){
      // Sobel 3×3 기울기로 밝기가 급변하는 경계를 찾는다.
      float du=1.0f/600, dv=du*ow/oh;
      float a=luma(sample(src,e,u-du,v-dv)),c=luma(sample(src,e,u+du,v-dv));
      float d=luma(sample(src,e,u-du,v)),f=luma(sample(src,e,u+du,v));
      float gg=luma(sample(src,e,u-du,v+dv)),hh=luma(sample(src,e,u,v+dv)),ii=luma(sample(src,e,u+du,v+dv));
      float top=luma(sample(src,e,u,v-dv));
      float gx=-a+c-2*d+2*f-gg+ii,gy=-a-2*top-c+gg+2*hh+ii;
      float edge=1-constrain((sqrt(gx*gx+gy*gy)-40)/160,0,0.92f);
      r=quant(br,5)*edge;g=quant(bg,5)*edge;b=quant(bb,5)*edge;
    }
    // 강도는 원본과 필터 결과의 선형 보간. 그 다음 밝기/대비/채도를 적용한다.
    r=lerp(br,constrain(r,0,255),e.strength);g=lerp(bg,constrain(g,0,255),e.strength);b=lerp(bb,constrain(b,0,255),e.strength);
    float gray=0.2126f*r+0.7152f*g+0.0722f*b;
    r=(lerp(gray,r,e.saturation)-127.5f)*e.contrast+127.5f+e.brightness;
    g=(lerp(gray,g,e.saturation)-127.5f)*e.contrast+127.5f+e.brightness;
    b=(lerp(gray,b,e.saturation)-127.5f)*e.contrast+127.5f+e.brightness;
    out.pixels[y*w+x]=(base&0xff000000)|(round(constrain(r,0,255))<<16)|(round(constrain(g,0,255))<<8)|round(constrain(b,0,255));
  }
  out.updatePixels();return out;
}
float quant(float v,int n){return round(v/255*(n-1))*255.0f/(n-1);}
float luma(int c){return 0.2126f*((c>>16)&255)+0.7152f*((c>>8)&255)+0.0722f*(c&255);}
int sample(PImage src,Edit e,float u,float v){
  if(e.flip)u=1-u;
  float a=u,b=v;
  if(e.turns==1){a=v;b=1-u;}
  else if(e.turns==2){a=1-u;b=1-v;}
  else if(e.turns==3){a=1-v;b=u;}
  int x=constrain((int)(a*src.width+0.001f),0,src.width-1),y=constrain((int)(b*src.height+0.001f),0,src.height-1);
  return src.pixels[y*src.width+x];
}

PImage makeCollage(boolean highResolution){
  int size=highResolution?2048:800;
  int gap=round(margin*size/2048.0f), cell=(size-3*gap)/2;
  PImage out=createImage(size,size,RGB);out.loadPixels();java.util.Arrays.fill(out.pixels,paper[bgIndex]);
  int[] four={0,1,2,3};
  for(int k=0;k<4;k++){
    Photo p=photos.get(collageMode==1?selected:picks.get(k));Edit e=p.edit.copy();
    if(collageMode==1)e.filter=four[k];
    PImage tile=renderImage(p.original,e,cell,false);tile.loadPixels();
    // 셀에 비율 유지하여 맞춤: 사진을 임의로 잘라내거나 늘리지 않는다.
    float sc=min(cell/(float)tile.width,cell/(float)tile.height);
    int tw=max(1,round(tile.width*sc)),th=max(1,round(tile.height*sc));
    int left=gap+(k%2)*(cell+gap)+(cell-tw)/2,top=gap+(k/2)*(cell+gap)+(cell-th)/2;
    for(int y=0;y<th;y++)for(int x=0;x<tw;x++){
      int c=tile.pixels[min(tile.height-1,y*tile.height/th)*tile.width+min(tile.width-1,x*tile.width/tw)];
      float a=((c>>>24)&255)/255.0f;int bg=paper[bgIndex];
      int r=round(lerp((bg>>16)&255,(c>>16)&255,a)),g=round(lerp((bg>>8)&255,(c>>8)&255,a)),b=round(lerp(bg&255,c&255,a));
      out.pixels[(top+y)*size+left+x]=0xff000000|(r<<16)|(g<<8)|b;
    }
  }
  out.updatePixels();return out;
}
