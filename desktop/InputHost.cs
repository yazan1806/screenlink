using System;
using System.Runtime.InteropServices;
using System.Web.Script.Serialization;
using System.Collections.Generic;
using System.Windows.Forms;
// Small, non-elevated input bridge. No command execution or clipboard access.
class InputHost {
 [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll",SetLastError=true)] static extern uint SendInput(uint n,INPUT[] input,int size);
 [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public UNION u; }
 [StructLayout(LayoutKind.Explicit)] struct UNION { [FieldOffset(0)] public MOUSE mi; [FieldOffset(0)] public KEY ki; }
 [StructLayout(LayoutKind.Sequential)] struct MOUSE { public int dx,dy; public uint data,flags,time; public UIntPtr extra; }
 [StructLayout(LayoutKind.Sequential)] struct KEY { public ushort vk,scan; public uint flags,time; public UIntPtr extra; }
 static void Mouse(uint flag,uint data=0){SendInput(1,new[]{new INPUT{type=0,u=new UNION{mi=new MOUSE{flags=flag,data=data}}}},Marshal.SizeOf(typeof(INPUT)));}
 static void Key(ushort vk,ushort scan,uint flags){SendInput(1,new[]{new INPUT{type=1,u=new UNION{ki=new KEY{vk=vk,scan=scan,flags=flags}}}},Marshal.SizeOf(typeof(INPUT)));}
 static Dictionary<string,ushort> keys=new Dictionary<string,ushort>{{"Enter",13},{"Backspace",8},{"Escape",27},{"Tab",9},{"ArrowLeft",37},{"ArrowUp",38},{"ArrowRight",39},{"ArrowDown",40},{"Delete",46}};
 static void Main(){SetProcessDPIAware();var json=new JavaScriptSerializer();string line;
  while((line=Console.ReadLine())!=null){if(line.Length>8192)continue;try{
   var d=json.Deserialize<Dictionary<string,object>>(line);string type=(string)d["type"];
   if(type=="click"||type=="move"){
    double x=Convert.ToDouble(d["x"]),y=Convert.ToDouble(d["y"]);if(double.IsNaN(x)||double.IsNaN(y)||x<0||x>1||y<0||y>1)continue;
    var b=Screen.PrimaryScreen.Bounds;SetCursorPos(b.Left+(int)(x*(b.Width-1)),b.Top+(int)(y*(b.Height-1)));
    if(type=="click"){Mouse(2);Mouse(4);}
   }else if(type=="scroll"){int amount=Math.Max(-1200,Math.Min(1200,Convert.ToInt32(d["delta"])));Mouse(0x800,unchecked((uint)amount));}
   else if(type=="key"){ushort k;if(keys.TryGetValue((string)d["key"],out k)){Key(k,0,0);Key(k,0,2);}}
   else if(type=="text"){string text=(string)d["text"];if(text.Length>1024)continue;foreach(char c in text){Key(0,c,4);Key(0,c,6);}}
  }catch{/* Invalid input is discarded, never interpreted as code. */}}
 }
}
