# TODO Lists：
## 完成 MVP 功能
先创建 Xcode 项目，然后通过 Trae AI 来补充功能生成 MVP。
1. 继续开发优化MVP
- 添加收付款方式，选择是用户记账之前事先添加好的，比如现金，招商银行卡，中信银行卡(6834)，微信，支付宝，招商信用卡(7894)带银行卡/信用卡尾号
2. 添加截图识别功能
- 使用 OCR 识别付款方，收款方，付款金额，收款金额，付款方式，收款方式，交易时间，商品说明，交易分类，备注
3. 添加智能识别功能
- 使用生成模型，识别付款方，收款方，付款金额，收款金额，付款方式，收款方式，交易时间，商品说明，交易分类，备注
4. 增加存储功能
- 存储到本地 numbers/wps/excel 中
5. 打包项目成 IOS app，方便用户使用，平替我目前使用的快捷指令。

6. 集成快捷指令：
快捷指令触发 -> 启动记账 App -> 截图 -> OCR 识图 -> Zhipu AI 处理 -> 数据填入记账页面 -> 用户 Review 修改 -> 保存/重置
初步的实现方案：APP 通过 URL （image base64 或者 imagepath base64）唤醒，
- 注册 URL Scheme
- 监听 onOpenURL，解析图片数据
- 自动 OCR 并填充表单
- 用户 review、修改、保存
这2个方案
第一方案主要原因还是 URL 长度超限，一张截图的 base64 编码+URL 编码后，长度依然远超 iOS URL Scheme 的限制。
第二个方案因为 传递的 imagepath 只是文件名或相对路径，不是完整的本地文件绝对路径。App 端用 URL(fileURLWithPath: decodedPath)，这会拼成 file:///On My iPhone/Image-5，但实际上 iOS 沙盒下的“文件”App路径并不是这样。App 没有权限直接访问“文件”App的路径，只能访问自己沙盒内的文件，或者通过 UIDocumentPicker/Share Extension 获取外部文件。

会导致：快捷指令输出：Invalid URL：XXX
Xcode 控制台输出：NSURLConnection finished with error - code -1002

因此通过下列两种方式实现：
1. Document Types 里加 public.image，你的 App 就能作为图片的目标出现在“拷贝到App”里。
2. 如果要直接在“分享”面板出现，需要实现 Share Extension。

### 目前进度：
1. Document Types 里加 public.image（“拷贝到App”）
进度：已完成！
你已经在主 App 的 Info.plist 里配置了 Document Types，支持 public.image。
这样你的 App 已经可以作为“拷贝到App”的目标出现在“文件”App、微信、QQ等支持“拷贝到App”的应用中。
用户可以在这些应用里长按图片，选择“拷贝到 SmartBookkeeping_LingMa2”，你的 App 会被唤起并收到图片文件的 URL。
2. Share Extension（直接在“分享”面板出现）
进度：已新建 Share Extension，尚未完成全部配置和调试。
你已经在 Xcode 里新建了 Share Extension target。
你已在 Info.plist 里配置了 NSExtensionActivationRule，但需要将其类型从字符串改为字典，并设置 NSExtensionActivationSupportsImageWithMaxCount = 1。
### 计划：：
你还需要在 Share Extension 的代码中实现图片的接收、保存到 App Group，并通过 URL Scheme 唤起主 App。
目前遇到 Apple App ID 创建上限，暂时无法为 Share Extension 创建新的 Provisioning Profile，需等待 7 天后再继续配置和真机调试。
你现在可以做什么？
“拷贝到App”方式已可用，可以在“文件”App等应用中测试图片导入主 App。
Share Extension 代码和配置可以继续完善，但真机调试需等 App ID 限制解除。
等待 7 天后，完成 Share Extension 的 Profile 配置，即可在“分享”面板直接看到你的 App 并接收图片。
后续建议
完善 Share Extension 的图片接收和数据回传主 App 逻辑（代码已给出模板）。
等待 App ID 限制解除后，完成 Profile 配置并真机测试。
如需进一步的 Share Extension 代码、App Group 配置、或调试指导，随时提问！

## UI 界面优化
```shell
# Test on localhost:8000
python3 -m http.server
```
```shell

git config --global user.name "MisterWJC"
git config --global user.email "wangjiacheng9602@gmail.com"

ssh-keygen -t ed25519 -C "wangjiacheng9602@gmail.com"

```
## 营销推广

```prompt
我要做一个账号打造 IP，主要记录自己从零开始入门 AI 应用开发。记录自己学习的过程，并形成一套体系，比如我一开始准备从 Transformer 入手去学习微调，以及对应的微调框架，从框架入手去做一个 AI 记账助手的项目来巩固微调相关的应用知识。将学习开发过程记录到微信视频号，哔哩哔哩可以进行录屏的长视频分享等自媒体平台。
对于项目也可以做成一个分路，挑战系列的短视频，挑战如何用 AI 一人团队花一个月时间打造一个智能记账 IOS app 并上架 app store，并通过该 app 盈利。

Progress:
目前的我自己的学习进度如下：
关于微调知识：
已经了解 GPT，BERT。但是不熟悉其与 Transformer 的关系以及底层的原理，当然对于应用开发的学习路线来讲，大模型的原理实现的次要的。更多的时候如果使用 Llamafactory，Xtuner 框架来做微调以及后续的 RAG，Agent，MCP 开发。

关于项目：
已经实现了一个 MVP 项目并且在 Xcode 中实现了记账的流程。
目前开发的 app 解决现有的记账 app 的核心痛点：
1. 极速记账功能：通过 OCR + 微调生成模型来快速记账，用户只需要一键触发记账流程之后审核修改结果即可。
2. 极简 app，支持导出功能，将流水信息导出。 
Problems:
目前开发的 app 有以下几个问题：
1. 模型微调之后的权重大小在大几百MB 乃至 1G+，因此将模型集成到 app 中，会导致 app 体积过大，并且在模型在首次加载的时候会很慢，影响用户记账效率。因此离线集成模型到 app 的方案被 pass。
2. 模型部署在云端服务器，App 通过 API 请求云端服务器，因此云端服务器需要部署多个实例，并且需要考虑高可用性。
3. 并且数据传输设计用户隐私条例，需要符合 Apple 的隐私条例，对数据进行加密。
4. 分类模型 Model Card for DistilBERT base multilingual 不能使用 LlamaFactory 进行微调。
Plan:
1. 将微调之后的模型转换成 GGUF 格式通过 Ollama 进行部署进行测试。看评测效果以及模型体积大小。
2. 部署模型到云端服务器，App 通过 API 请求云端服务器交互获取具体的账单信息。

让我们来头脑风暴一下接下来需要做哪些准备工作进行营销推广，如何去记录自己的第一个视频来介绍要做的事情，来吸引用户关注。

```
IP 核心定位：
从零开始入门 AI 应用开发，
从微调出发，打造一个智能记账大模型并集成到 IOS App，拆解目前市面上的几种实现方式，项目会用到 Bert 分类模型，以及微调 GPT 生成模型。以及调用大模型 API。
第二步是 MCP-自定义 MCP Server，Agent，RAG 的开发，以及后续的部署。

内容创作的通用准备（针对每一条内容）：
[ ] 确定核心信息点与目标受众： 这部分内容是给谁看的？他们看完能学到什么？
[ ] 撰写脚本/大纲： 梳理讲解逻辑、关键演示步骤、预期时长。
[ ] 准备素材： 录屏、PPT/Keynote、代码片段、演示环境、必要的图表或动画示意。
[ ] 录制与剪辑： 保证音画清晰，节奏适当，添加必要的字幕和说明。
[ ] 设计吸引人的标题和封面。


