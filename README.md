# polyglot_swift

一个mac下获取系统speaker声道，转录生成字幕并翻译的小工具.

A small tool for obtaining the system speaker channel on Mac, transcribing it to generate subtitles and translating it

这个工具是用来监听mac系统的声音（非mic），然后将声音进行实时的转录和翻译的小工具。为了保证效率和少花钱，所有的功能都在本地运行，没有联网的需求。
其中技术清单如下：

This tool is used to monitor the sound of the Mac system (not the mic), and then transcribe and translate the sound in real time. In order to ensure efficiency and save money, all functions are run locally, and there is no need to connect to the Internet.
The technical list is as follows:

1，感谢 / Thanks [BlackHole](https://github.com/ExistentialAudio/BlackHole)

安装方式 Installation：

```shell
brew install blackhole-2ch
```

目前我测试用的是2ch
安装后，在mac osx的dashboard里找到 Audio MIDI Setup，看到有black hole的设备后表示安装成功了。 

I am currently testing with 2ch
After installation, find Audio MIDI Setup in the Mac OSX dashboard, and when you see a device with a black hole, it means the installation is successful.

<img src="https://raw.githubusercontent.com/ethanzhrepo/PolyglotSwift/refs/heads/main/assets/3.png" width="500px"/>

点击左下角➕，添加一个Multi-Output Device
Click the ➕ button in the lower left corner to add a Multi-Output Device

这个时候点击系统状态栏的小喇叭，会多一个输出设备，将声音切换到这个输出设备上来（会有个bug，就是切换后没办法调整音量了，所以在切换前调整好音量）

At this time, click the small speaker in the system status bar, and there will be an additional output device, and the sound will be switched to this output device (there will be a bug, that is, the volume cannot be adjusted after switching, so adjust the volume before switching)

<img src="https://raw.githubusercontent.com/ethanzhrepo/PolyglotSwift/refs/heads/main/assets/4.png" width="300px"/>

2、在本地启动一个翻译模型，我用的是  

Start a translation model locally (No way, the translation interface is too expensive for me. If you prefer the translation interface of Google/Azure/DeepL/ChatGPT, etc., you can implement it yourself.)

[https://huggingface.co/Helsinki-NLP/opus-mt-en-zh](https://huggingface.co/Helsinki-NLP/opus-mt-en-zh)

写个python程序启动它（自己用conda安装个python3环境，其余的依赖去问gpt）：

Write a python program to start it (use conda to install a python3 environment yourself, and ask gpt for the rest of the dependencies)

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

# 加载模型
tokenizer = AutoTokenizer.from_pretrained("Helsinki-NLP/opus-mt-en-zh")
model = AutoModelForSeq2SeqLM.from_pretrained("Helsinki-NLP/opus-mt-en-zh")

# 定义 FastAPI 应用
app = FastAPI()

class TranslationRequest(BaseModel):
    text: str

@app.post("/translate/")
def translate(request: TranslationRequest):
    input_text = request.text
    inputs = tokenizer(input_text, return_tensors="pt")
    outputs = model.generate(**inputs)
    translated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
    return {"translated_text": translated_text}
```

执行启动 / Start translation service

```shell
# FOR INSTAll
#  pip install fastapi uvicorn transformers torch

uvicorn api_server:app --host 127.0.0.1 --port 8000
```

这个时候8000端口就有了一个翻译工具。测试一下：

Now we have a translation tool on port 8000. Test it:

```shell
curl -X POST http://127.0.0.1:8000/translate/ \
>      -H "Content-Type: application/json" \
>      -d '{"text": "Hello, how are you?"}'
```

Returns

```shell
{"translated_text":"你好,你好吗?"}
```



3、接下来打开任意英文音频或者打开视频会议或者打开在线视频，开始播放，因为multi-output的缘故，speaker也会发声，点击程序的“Start”, 屏幕上会出现一个底色为半透明的 可拖动的浮层，实时监听来自blackhole虚拟设备的声音流，并将其转录和翻译出来。

Next, open any English audio or video conference or online video and start playing. Because of multi-output, the speaker will also make sound. Click "Start" of the program, and a draggable floating layer with a semi-transparent background will appear on the screen, which monitors the sound stream from the blackhole virtual device in real time and transcribes and translates it.

<img src="https://raw.githubusercontent.com/ethanzhrepo/PolyglotSwift/refs/heads/main/assets/5.png" width="500px"/>

<img src="https://raw.githubusercontent.com/ethanzhrepo/PolyglotSwift/refs/heads/main/assets/1.png" width="500px"/>

TODO:

What else is not done?

- Use NLP to segment natural sentences.

--------

声明：我并不懂swift代码，这是第一次开发macos app，几乎所有的代码由ai助手来完成，人类只负责引导ai和对代码进行微调。感谢ai的发展，致敬人类最伟大的工程师们。
Disclaimer: I don't understand Swift code. This is my first time developing a macOS app. Almost all the code is done by AI assistants. Humans are only responsible for guiding AI and fine-tuning the code. Thanks to the development of AI, I salute the greatest engineers in the world.
