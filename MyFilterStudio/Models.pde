class Edit {
  int filter=0, turns=0, seed=137;
  float brightness=0, contrast=1, saturation=1, strength=1, pixel=1.5f;
  boolean flip=false;
  float cx=0,cy=0,cw=1,ch=1;
  void clearCrop(){cx=cy=0;cw=ch=1;}
  Edit copy(){
    Edit e=new Edit();e.filter=filter;e.turns=turns;e.seed=seed;e.brightness=brightness;e.contrast=contrast;e.saturation=saturation;e.strength=strength;e.pixel=pixel;e.flip=flip;e.cx=cx;e.cy=cy;e.cw=cw;e.ch=ch;return e;
  }
}
class Photo {
  PImage original,thumb;
  String name;
  Edit edit=new Edit();
  Photo(PImage source,String title){
    original=source; name=title; thumb=source.get();
    if(max(thumb.width,thumb.height)>600){float s=600.0f/max(thumb.width,thumb.height);thumb.resize(max(1,round(thumb.width*s)),max(1,round(thumb.height*s)));}
    edit.seed=photos.size()*7919+137;
  }
}
class Button {
  String id,label;float x,y,w,h;boolean enabled,selected;
  Button(String i,String l,float a,float b,float c,float d,boolean s,boolean e){id=i;label=l;x=a;y=b;w=c;h=d;selected=s;enabled=e;}
  boolean hit(float a,float b){return a>=x&&a<x+w&&b>=y&&b<y+h;}
  void display(){
    noStroke();fill(!enabled?color(32,38,50):selected?color(49,137,124):hit(mx,my)?color(67,80,101):color(43,53,71));rect(x,y,w,h,6);
    fill(enabled?color(235):color(101,114,132));textSize(12);textAlign(CENTER,CENTER);text(label,x+w/2,y+h/2-1);textAlign(LEFT,BASELINE);
  }
}
void button(String id,String label,float x,float y,float w,float h,boolean selected,boolean enabled){Button b=new Button(id,label,x,y,w,h,selected,enabled);buttons.add(b);b.display();}
class Slider {
  String id;float y,value,lo,hi;boolean enabled;
  Slider(String i,float yy,float v,float l,float h,boolean e){id=i;y=yy;value=v;lo=l;hi=h;enabled=e;}
  boolean hit(float x,float yy){return x>=918&&x<=1170&&yy>=y+14&&yy<=y+42;}
}
void slider(String id,String label,float value,float lo,float hi,float y,boolean enabled){
  Slider s=new Slider(id,y,value,lo,hi,enabled);sliders.add(s);
  fill(enabled?color(186,198,215):color(99,111,129));textSize(12);text(label,918,y+8);textAlign(RIGHT);text(id.equals("brightness")?str(round(value)):nf(value,1,2),1170,y+8);textAlign(LEFT);
  fill(51,61,78);rect(918,y+26,252,4,2);fill(enabled?color(75,208,178):color(82,98,110));ellipse(map(value,lo,hi,918,1170),y+28,13,13);
}
void setSlider(Slider s){
  float v=map(constrain(mx,918,1170),918,1170,s.lo,s.hi);Edit e=currentEdit();
  if(s.id.equals("brightness"))e.brightness=v;
  if(s.id.equals("contrast"))e.contrast=v;
  if(s.id.equals("saturation"))e.saturation=v;
  if(s.id.equals("strength"))e.strength=v;
  if(s.id.equals("pixel"))e.pixel=v;
  changed();
}
