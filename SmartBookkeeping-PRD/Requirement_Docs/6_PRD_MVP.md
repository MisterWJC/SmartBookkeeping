# 智能记账助手 MVP - 产品需求文档 (PRD)

## 1. 产品背景和目标

**产品背景：**
现代生活中，移动支付日益普及，用户在线上或线下完成付款或收款后，往往需要手动记录收支情况，这一过程繁琐、耗时且容易遗漏，导致用户难以坚持记账，无法有效掌握个人财务状况。

**产品要解决的核心问题：**
解决手动记账效率低下、操作不便的痛点，通过智能化手段简化记账流程，帮助用户轻松、准确地记录每一笔收支。

**服务场景：**
用户在线上（如电商购物、扫码支付）或线下（如实体店消费）使用移动支付（如微信支付、支付宝）完成付款或收款后，希望快速记录该笔交易的场景。

**核心目标：**
*   **MVP核心目标：** 快速、准确地通过截图识别支付/收款凭证的关键信息，实现一键智能记账，并提供基础的账单管理和数据导出功能，让用户能够轻松开始并坚持记账。
*   **长期目标：** 成为用户首选的智能记账工具，提供全面的财务分析和管理功能，帮助用户更好地理解和规划个人财务。

## 2. 核心功能模块列表 (MVP)

| 功能模块                 | 功能描述                                                                                                                               | 使用场景                                                                                                | 这个功能解决的问题                                                                 |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| **1. 截图智能识别记账**  | 用户通过截取支付/收款凭证图片，App自动识别关键信息（金额、时间、商品说明、交易分类（固定）、收/支、付款/收款方式、备注）并预填充账单。                                        | 用户完成移动支付/收款后，截取凭证图片，希望快速完成记账。                                                              | 手动记账繁琐、耗时、易遗漏，难以坚持。                                                          |
| **2. 手动记账与编辑**    | 允许用户手动添加新账单，或对已识别/已创建的账单信息进行修改和补充，确保数据准确性。                                                              | 截图识别有误或信息不全时；部分消费无电子凭证（如现金支付）时；用户需要修正已记录账单时。                                                | 保证记账数据的准确性和完整性，覆盖所有记账场景。                                       |
| **3. 账单列表展示**    | 清晰展示所有记账记录，按时间倒序排列。每条记录概要显示关键信息（日期、分类、金额、简要说明）。                                                                 | 用户需要查看、回顾、查找自己的收支记录。                                                                    | 用户需要方便地回顾和查找自己的收支记录。                                                            |
| **4. 固定交易分类**    | 提供一组不可编辑的、常用的支出和收入分类。用户在记账时（无论是截图识别后确认还是手动记账）可以选择或修改该条记录的分类。                                               | 用户记账时，需要为每笔交易归类，以便后续统计分析。                                                              | 用户需要对收支进行归类，以便更好地理解消费构成。                                                      |
| **5. 基础收支汇总**    | 在App的某个位置（如首页或简单报表页）展示当月的总支出、总收入。                                                                              | 用户希望快速了解当月大致的财务状况。                                                                      | 用户记账后希望快速了解自己的整体财务状况，但无需复杂分析。                                                |
| **6. 本地数据存储**    | 所有账单数据安全存储在用户设备本地（如SQLite数据库），确保用户数据的隐私和可访问性。                                                                   | App需要持久化存储用户的记账数据。                                                                       | 保证用户数据的安全性和隐私性，避免数据丢失。                                                       |
| **7. 数据导出 (CSV/Excel格式)** | 允许用户将账单数据按指定时间范围导出为通用表格格式（如CSV、Excel），以便在其他软件中查看、备份或进一步分析。                                                        | 用户希望备份账单数据；用户希望在电脑上或其他专业软件中对账单数据进行更复杂的分析或处理。                                          | 满足用户数据备份、迁移和在其他工具中复用数据的需求。                                         |

## 3. 用户流程图 (MVP - 文字版)

**场景一：首次使用与权限授予**
1.  用户下载并首次打开 App。
2.  App 展示欢迎引导页，简要介绍核心功能（特别是截图记账）。
3.  App 请求必要的权限：
    *   相册访问权限（用于读取用户选择的截图或自动检测剪贴板截图）。
    *   (可选，根据实现方式) 通知权限（用于提醒用户记账或账单确认）。
4.  用户授予权限。

**场景二：通过截图智能记账**
1.  用户在其他应用（如支付宝、微信）完成支付或收款，并截取凭证图片。
2.  用户打开智能记账助手 App。
3.  App 自动检测到剪贴板中的新截图或提示用户从相册选择截图。
    *   *备选方案：* 用户通过系统分享菜单将截图分享到本App。
4.  用户确认使用该截图进行记账。
5.  App 对选定的截图进行 OCR 识别，提取账单关键信息（金额、时间、对方信息、商品说明等）。
6.  App 预填充账单表单，并根据识别内容尝试自动匹配交易分类（固定分类）。
7.  用户在账单确认页面检查识别结果，可手动修改金额、日期、分类（从固定列表中选择）、添加备注、确认收/支类型、付款/收款方式。
8.  用户点击“保存”，账单记录成功存储到本地。
9.  App 返回账单列表页或首页，新记录可见。

**场景三：手动记账**
1.  用户在 App 内点击“手动记账”或“+”按钮。
2.  用户进入记账页面，手动输入/选择以下信息：
    *   金额
    *   日期（默认为当天，可修改）
    *   交易分类（从固定列表中选择）
    *   收/支类型
    *   付款/收款方式（可选填）
    *   商品说明/备注（可选填）
3.  用户点击“保存”，账单记录成功存储到本地。
4.  App 返回账单列表页或首页，新记录可见。

**场景四：查看与编辑/删除账单**
1.  用户进入“账单列表”页面。
2.  App 展示按时间倒序排列的账单流水，每条显示关键信息。
3.  用户点击某条账单，进入账单详情页面查看完整信息。
4.  在详情页，用户可选择“编辑”该条账单：
    *   进入类似手动记账的编辑界面，修改信息后保存。
5.  在详情页或列表页（通过滑动等手势），用户可选择“删除”该条账单。
    *   App 弹出确认提示。
    *   用户确认后，账单被删除。

**场景五：查看基础收支汇总**
1.  用户进入App首页或指定的“汇总”/“概览”页面。
2.  App 展示当月的总支出和总收入金额。

**场景六：数据导出**
1.  用户进入“设置”或“更多”页面。
2.  用户选择“数据导出”功能。
3.  用户选择导出格式（CSV 或 Excel）。
4.  (可选) 用户选择导出时间范围（如本月、上月、所有数据）。
5.  App 生成数据文件，用户可选择保存到设备本地存储或通过系统分享功能发送到其他应用（如邮件、网盘）。

## 4. 每个功能的输入/输出 (MVP)

**1. 截图智能识别记账**
*   **用户输入：**
    *   支付/收款凭证截图 (图片文件)。
    *   确认使用该截图的动作。
    *   (在确认页面) 可能的修改：金额、日期、分类、备注、收/支类型、付款/收款方式。
*   **系统输入：**
    *   OCR识别引擎的配置参数。
    *   固定的交易分类列表。
*   **期望输出：**
    *   结构化的账单数据对象，包含：付款金额、交易时间、商品说明、交易分类、收入/支出标记、付款方式、备注。
    *   预填充的账单确认界面。
    *   成功保存账单的提示。
    *   更新后的账单列表。

**2. 手动记账与编辑**
*   **用户输入：**
    *   **手动记账：** 金额、日期、交易分类、收/支类型、付款/收款方式（可选）、商品说明/备注（可选）。
    *   **编辑账单：** 对已有账单的上述字段进行修改。
    *   保存动作。
*   **系统输入：**
    *   固定的交易分类列表。
    *   (编辑时) 原始账单数据。
*   **期望输出：**
    *   新建或更新的结构化账单数据对象。
    *   成功保存/更新账单的提示。
    *   更新后的账单列表。

**3. 账单列表展示**
*   **用户输入：**
    *   进入账单列表页的导航动作。
    *   (未来可能) 筛选条件（如按月份、按分类）。
    *   (未来可能) 搜索关键词。
*   **系统输入：**
    *   本地存储的所有账单数据。
*   **期望输出：**
    *   按时间倒序排列的账单列表UI，每条目包含关键信息。

**4. 固定交易分类**
*   **用户输入：**
    *   在记账或编辑账单时，从分类列表中选择一个分类。
*   **系统输入：**
    *   预设的固定交易分类数据（支出和收入两大类及其子类）。
*   **期望输出：**
    *   用户选择的分类被关联到对应的账单记录上。
    *   账单表单中正确显示和选定分类。

**5. 基础收支汇总**
*   **用户输入：**
    *   进入汇总展示页面的导航动作。
*   **系统输入：**
    *   当月所有已记录的账单数据。
*   **期望输出：**
    *   UI上清晰展示当月总支出金额和总收入金额。

**6. 本地数据存储**
*   **用户输入：**
    *   隐式输入：所有创建和编辑账单的操作都会触发数据存储。
*   **系统输入：**
    *   结构化的账单数据对象。
*   **期望输出：**
    *   账单数据被安全、持久地存储在用户设备本地。
    *   数据读取操作能够正确返回已存储的数据。

**7. 数据导出 (CSV/Excel格式)**
*   **用户输入：**
    *   选择导出功能的动作。
    *   选择导出格式 (CSV/Excel)。
    *   (可选) 选择导出时间范围。
    *   确认导出并选择保存路径/分享方式。
*   **系统输入：**
    *   本地存储的符合条件的账单数据。
*   **期望输出：**
    *   一个符合选定格式 (CSV/Excel) 的账单数据文件。
    *   文件成功保存到用户指定位置或成功通过系统分享的提示。

## 5. 接口需求 (MVP)

*   **OCR识别接口 (核心外部依赖):**
    *   **用途：** 从用户提供的截图中提取文本信息。
    *   **调用方式：**
        *   **方案A (云端API)：** App将截图上传至云端OCR服务，接收识别出的文本结果。需要考虑API Key管理、网络请求、费用等。
        *   **方案B (本地SDK/系统能力)：** App集成设备本地的OCR SDK或利用操作系统提供的OCR能力（如iOS的Vision框架）。可能需要处理SDK集成、模型大小、设备兼容性问题。
    *   **数据结构要求 (输入)：** 图片文件 (JPEG, PNG等)。
    *   **数据结构要求 (输出)：** 包含识别出的文本块及其位置信息（可选）的JSON或结构化数据。
    *   *注意：* App内部还需要一个解析模块，将OCR原始文本结果进一步处理成结构化的账单字段。

*   **本地数据库接口 (核心内部依赖):**
    *   **用途：** 存储、读取、更新、删除用户的账单数据。
    *   **调用方式：** App通过本地数据库API (如SQLite API) 与数据库交互。
    *   **数据结构要求 (输入/输出)：** 结构化的账单对象/记录。

*   **文件系统接口 (用于数据导出):**
    *   **用途：** 创建和写入CSV/Excel文件到用户设备存储。
    *   **调用方式：** App通过操作系统提供的文件系统API进行文件操作。
    *   **数据结构要求 (输入)：** 结构化的账单数据列表。
    *   **数据结构要求 (输出)：** 文件句柄或保存成功状态。

*   **系统分享接口 (用于数据导出):**
    *   **用途：** 调用操作系统的分享功能，允许用户将导出的文件发送到其他应用。
    *   **调用方式：** App通过操作系统提供的分享API (如iOS的UIActivityViewController, Android的Intent)。
    *   **数据结构要求 (输入)：** 要分享的文件URI或数据。

## 6. 边界条件和异常处理 (MVP)

**1. 截图智能识别记账**
*   **边界条件：**
    *   截图质量极低，模糊不清。
    *   非标准支付凭证截图（如广告、聊天截图）。
    *   截图信息不完整（如金额被遮挡）。
    *   截图包含多笔交易信息。
    *   非常规金额格式或日期格式。
*   **异常处理：**
    *   **识别失败/信息不全：** 提示用户识别效果不佳，引导用户手动输入或编辑关键信息。允许用户跳过识别，直接进入手动记账。
    *   **非凭证截图：** 提示无法识别为有效凭证，请用户选择正确的截图。
    *   **OCR服务不可用 (云端API)：** 提示网络错误或服务暂时不可用，建议稍后重试或使用手动记账。
    *   **权限未授予：** 提示需要相册访问权限，并引导用户去系统设置中开启。

**2. 手动记账与编辑**
*   **边界条件：**
    *   用户输入无效金额（如非数字、负数金额用于支出）。
    *   用户选择未来日期进行记账（通常允许，但需明确）。
    *   备注或商品说明过长。
*   **异常处理：**
    *   **无效输入：** 实时校验用户输入，对无效内容给出提示（如金额必须为数字）。保存时进行最终校验，阻止无效数据保存。
    *   **备注过长：** 限制输入长度或友好提示。

**3. 账单列表展示**
*   **边界条件：**
    *   没有任何账单记录（新用户）。
    *   账单记录非常多，加载性能。
*   **异常处理：**
    *   **无记录：** 显示空状态提示，引导用户开始记账。
    *   **加载性能：** MVP阶段数据量预计不大，后续可考虑分页加载或虚拟列表优化。

**4. 本地数据存储**
*   **边界条件：**
    *   设备存储空间不足。
    *   数据库文件损坏。
*   **异常处理：**
    *   **存储空间不足：** 尝试保存时，若失败则提示用户清理设备空间。
    *   **数据库损坏：** 启动时检测，若损坏则提示用户可能数据丢失，并尝试恢复（若有备份机制）或初始化。MVP阶段可能简化为提示数据问题。

**5. 数据导出**
*   **边界条件：**
    *   无可导出数据。
    *   导出过程中用户取消操作。
    *   设备存储空间不足以保存导出文件。
*   **异常处理：**
    *   **无数据：** 提示用户当前没有可导出的账单记录。
    *   **用户取消：** 正常中止导出流程。
    *   **存储空间不足：** 提示用户清理设备空间。
    *   **文件写入失败：** 提示导出失败，原因可能是权限或存储问题。

**通用异常：**
*   **网络连接问题 (若使用云端OCR)：** 友好提示网络错误，建议检查网络连接或稍后重试。
*   **应用崩溃/未知错误：** 尽可能捕获异常，提供反馈渠道，避免直接闪退。MVP阶段可简化处理。

## 7. 快捷操作与优化思路参考 (基于iPhone快捷指令)

本章节参考用户提供的 iPhone 快捷指令记账链路，分析其可借鉴的优化实现方式，并探讨 MVP 版本可以如何模仿或优化现有流程。

**iPhone 快捷指令链路回顾：**
1.  **触发方式：** 点击手机侧边键触发快捷指令。
2.  **核心操作：** 自动截图 -> OCR识别文本 -> 用户交互手动选择/确认信息（交易时间、商品说明、分类、收支、付款方式、备注） -> 存储至 Numbers。

**可借鉴的优化点分析：**

1.  **触发便捷性：**
    *   **借鉴点：** 侧边键触发非常快捷，最大限度减少了用户操作步骤。
    *   **MVP优化思考：**
        *   **强化分享扩展（Share Extension）：** 确保用户在任何应用截图后，能通过系统分享菜单快速将图片发送到“智能记账助手”进行处理，这是最接近快捷指令便利性的跨应用操作方式。
        *   **剪贴板监控：** App 激活时自动检测剪贴板中是否有新的截图，并提示用户是否用于记账（已在场景二中提及，可进一步优化提示的即时性和非干扰性）。
        *   **(远期或平台特性)：** 探索如 Android 的快捷设置瓷贴 (Quick Settings Tile)、iOS 的小组件 (Widgets) 或锁屏小组件，提供快速入口。

2.  **用户交互效率：**
    *   **借鉴点：** 快捷指令在 OCR 后直接引导用户进行关键信息的选择和确认，流程直接。
    *   **MVP优化思考：**
        *   **优化OCR后信息确认界面：** 虽然 MVP 强调自动识别和预填充，但在用户检查和修改环节（场景二，步骤7），应确保界面清晰、操作流畅。对于OCR识别不准或未能覆盖的字段（如备注、特定分类），提供快速的手动选择/输入方式，体验上力求接近快捷指令中选择的直接感。
        *   **字段交互优化：** 例如，对于固定分类、收支类型、付款方式等，使用选择器或按钮组，减少键盘输入，提升选择效率。

3.  **流程模仿与MVP整合：**
    *   **核心思想保留：** MVP 的“通过截图智能记账”流程（场景二）的核心思想（截图 -> OCR -> 结构化 -> 用户确认 -> 保存）与快捷指令的本质是一致的，且更为智能（增加了自动匹配和预填充）。
    *   **MVP侧重：** MVP 应保持其智能识别的优势，同时吸取快捷指令在“触发”和“手动校正效率”上的优点。
    *   **具体建议：**
        *   在“场景二：通过截图智能记账”的用户流程中，可以补充说明对触发方式便捷性的追求，例如优先引导用户使用分享扩展。
        *   在设计账单确认和编辑页面时，特别关注操作的流畅性和便捷性，确保用户能快速完成信息的核对与修改。

4. **快捷指令的痛点：**
     1. 开发者受到限制，无法实现更复杂的功能，如：在用户交互的步骤中，如果用户填错信息或者选择错选项无法返回，只能退出流程重新触发指令。
     2. 框架受限制，只能用苹果提供的一些指令来做开发。个性化功能受到限制。
**结论：**

iPhone 快捷指令提供了一个极致简化手动操作的优秀范例。对于智能记账助手 MVP 而言，其核心优势在于“智能”，即 OCR 自动提取与预填充。MVP 可以借鉴快捷指令的“触发便捷性”和“交互直接性”来优化用户体验，特别是在截图导入和信息校正环节。MVP 不必完全复制其手动选择所有字段的模式，而是应在智能化的基础上，让用户的手动干预过程也同样高效快捷。