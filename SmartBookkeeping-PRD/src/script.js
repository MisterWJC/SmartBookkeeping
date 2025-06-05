document.addEventListener('DOMContentLoaded', () => {
    const billForm = document.querySelector('form');
    const billListContainer = document.querySelector('.bill-list');
    const screenshotInput = document.getElementById('screenshot');

    // Load bills from localStorage
    let bills = JSON.parse(localStorage.getItem('bills')) || [];

    // Function to render bills
    const renderBills = () => {
        // Clear existing bill items except the h2
        const existingItems = billListContainer.querySelectorAll('.bill-item');
        existingItems.forEach(item => item.remove());

        if (bills.length === 0) {
            const noBillsMessage = document.createElement('p');
            noBillsMessage.textContent = '暂无账单记录。';
            noBillsMessage.style.textAlign = 'center';
            noBillsMessage.style.color = '#888';
            billListContainer.appendChild(noBillsMessage);
        }

        bills.sort((a, b) => new Date(b.date) - new Date(a.date)); // Sort by date descending

        bills.forEach((bill, index) => {
            const billItem = document.createElement('div');
            billItem.classList.add('bill-item');
            billItem.dataset.index = index;

            const billInfo = document.createElement('div');
            billInfo.classList.add('bill-info');

            const billAmount = document.createElement('span');
            billAmount.classList.add('bill-amount');
            billAmount.textContent = `${bill.type === 'expense' ? '-' : '+'} ¥${parseFloat(bill.amount).toFixed(2)}`;
            billAmount.style.color = bill.type === 'expense' ? '#f36c6c' : '#8fd16a'; // Red for expense, Green for income

            const billMeta = document.createElement('span');
            billMeta.classList.add('bill-meta');
            const billDate = bill.date ? new Date(bill.date).toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' }) : '无日期';
            const billCategoryText = document.querySelector(`#category option[value="${bill.category}"]`)?.textContent || bill.category || '未分类';
            billMeta.textContent = `${billDate} · ${billCategoryText} · ${bill.method || 'N/A'}`;
            
            billInfo.appendChild(billAmount);
            billInfo.appendChild(billMeta);

            const billActions = document.createElement('div');
            billActions.classList.add('bill-actions');

            const editButton = document.createElement('button');
            editButton.textContent = '编辑';
            editButton.addEventListener('click', () => loadBillForEditing(index));

            const deleteButton = document.createElement('button');
            deleteButton.textContent = '删除';
            deleteButton.addEventListener('click', () => deleteBill(index));

            billActions.appendChild(editButton);
            billActions.appendChild(deleteButton);

            billItem.appendChild(billInfo);
            billItem.appendChild(billActions);

            billListContainer.appendChild(billItem);
        });
        updateSummary();
    };

    // Function to save bills to localStorage
    const saveBills = () => {
        localStorage.setItem('bills', JSON.stringify(bills));
    };

    // Handle form submission
    billForm.addEventListener('submit', (event) => {
        event.preventDefault();

        const amount = document.getElementById('amount').value;
        const date = document.getElementById('date').value;
        const desc = document.getElementById('desc').value;
        const category = document.getElementById('category').value;
        const type = document.getElementById('type').value;
        const method = document.getElementById('method').value;
        const note = document.getElementById('note').value;
        const editingIndex = billForm.dataset.editingIndex;

        if (!amount || !date || !category || !type) {
            alert('金额、交易时间、交易分类和收/支类型为必填项！');
            return;
        }

        const newBill = {
            amount: parseFloat(amount),
            date,
            desc,
            category,
            type,
            method,
            note
        };

        if (editingIndex !== undefined) {
            bills[editingIndex] = newBill;
            delete billForm.dataset.editingIndex; // Clear editing state
            billForm.querySelector('.save').textContent = '保存';
        } else {
            bills.push(newBill);
        }

        saveBills();
        renderBills();
        billForm.reset();
        document.getElementById('date').value = ''; // Clear datetime-local specifically
    });

    // Handle form reset
    billForm.addEventListener('reset', () => {
        delete billForm.dataset.editingIndex;
        billForm.querySelector('.save').textContent = '保存';
        document.getElementById('date').value = ''; // Clear datetime-local specifically
    });

    // Function to load bill data into form for editing
    const loadBillForEditing = (index) => {
        const bill = bills[index];
        document.getElementById('amount').value = bill.amount;
        document.getElementById('date').value = bill.date;
        document.getElementById('desc').value = bill.desc;
        document.getElementById('category').value = bill.category;
        document.getElementById('type').value = bill.type;
        document.getElementById('method').value = bill.method;
        document.getElementById('note').value = bill.note;

        billForm.dataset.editingIndex = index;
        billForm.querySelector('.save').textContent = '更新';
        window.scrollTo(0, 0); // Scroll to top to see the form
    };

    // Function to delete a bill
    const deleteBill = (index) => {
        if (confirm('确定要删除这条账单吗？')) {
            bills.splice(index, 1);
            saveBills();
            renderBills();
        }
    };

    // ------------- OCR Integration START -------------
    /**
     * Simulates OCR processing and data extraction.
     * In a real application, this function would interact with an OCR service.
     * @param {string} textContent The raw text extracted by OCR.
     * @returns {object} An object containing extracted bill information.
     */
    const parseOCRText = (textContent) => {
        const extractedData = {
            amount: null,
            date: null,
            desc: '',
            category: '',
            type: '', // 'income' or 'expense'
            method: '',
            note: ''
        };

        // --- Placeholder Parsing Logic (Highly Simplified) ---
        // This needs to be replaced with robust parsing based on expected screenshot formats.

        // Example: Extract Amount (e.g., "金额: ¥123.45", "消费：123.45元")
        let amountMatch = textContent.match(/(?:金额|消费|付款|收款|总计)[:：¥\s]*([\d,]+\.?\d*)/);
        if (amountMatch && amountMatch[1]) {
            extractedData.amount = parseFloat(amountMatch[1].replace(',', ''));
        }

        // Example: Extract Date (e.g., "2024-01-15 10:30", "24年01月15日 10时30分")
        // This needs to handle various date formats and convert to YYYY-MM-DDTHH:MM
        let dateMatch = textContent.match(/(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})[日T\s]*(\d{1,2})[:：时](\d{1,2})/);
        if (dateMatch) {
            const [, year, month, day, hour, minute] = dateMatch;
            extractedData.date = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}T${hour.padStart(2, '0')}:${minute.padStart(2, '0')}`;
        } else {
             // Try another common pattern
            dateMatch = textContent.match(/(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{1,2})/);
            if (dateMatch) {
                const currentYear = new Date().getFullYear();
                const [, month, day, hour, minute] = dateMatch;
                extractedData.date = `${currentYear}-${month.padStart(2, '0')}-${day.padStart(2, '0')}T${hour.padStart(2, '0')}:${minute.padStart(2, '0')}`;
            }
        }


        // Example: Extract Type (income/expense)
        if (textContent.includes('收入') || textContent.includes('收款成功')) {
            extractedData.type = 'income';
        } else if (textContent.includes('支出') || textContent.includes('消费') || textContent.includes('付款成功')) {
            extractedData.type = 'expense';
        }
        // Fallback: if an amount is found but type is unknown, prompt user or default to expense
        if (extractedData.amount && !extractedData.type) {
             extractedData.type = 'expense'; // Default or requires more logic
        }


        // Example: Extract Method (e.g., "微信支付", "支付宝")
        if (textContent.includes('微信')) extractedData.method = '微信';
        else if (textContent.includes('支付宝')) extractedData.method = '支付宝';
        else if (textContent.match(/银行卡|信用卡|储蓄卡/)) extractedData.method = '银行卡';


        // Example: Extract Description (e.g., "商品说明:", "付款给")
        // This is highly dependent on the bill format.
        // It might look for "商品", "说明", "订单", "收款方", "付款给" etc.
        let descMatch = textContent.match(/(?:商品说明|订单信息|交易对方|收款方)[:：\s]*(.+?)(?:\n|金额|$)/);
        if (descMatch && descMatch[1]) {
            extractedData.desc = descMatch[1].trim();
        } else if (extractedData.method) { // If no specific description, use a generic one
             extractedData.desc = `通过${extractedData.method}的交易`;
        }


        // Example: Attempt to map category (very basic)
        if (extractedData.desc) {
            if (extractedData.desc.includes('餐饮') || textContent.match(/美团|饿了么|餐厅|饭店|外卖/)) extractedData.category = 'food';
            else if (extractedData.desc.includes('购物') || textContent.match(/淘宝|京东|超市|便利店|商城/)) extractedData.category = 'shopping';
            else if (extractedData.desc.includes('交通') || textContent.match(/滴滴|公交|地铁|油费|停车/)) extractedData.category = 'transport';
            else if (extractedData.desc.includes('房租') || extractedData.desc.includes('水电')) extractedData.category = 'housing';
        }
        
        // Placeholder for payee/payer or notes:
        // extractedData.note = "Extracted Payer: ... Payee: ...";

        console.log("Extracted OCR Data:", extractedData);
        return extractedData;
    };

    /**
     * Placeholder for actual OCR processing.
     * @param {File} file The image file to process.
     * @returns {Promise<string>} A promise that resolves with the OCR text result.
     */
    const performOCR = async (file) => {
        // --- THIS IS A SIMULATION ---
        // In a real app, you would use a library like Tesseract.js or call a cloud OCR API.
        // For example, with Tesseract.js:
        // const { data: { text } } = await Tesseract.createWorker().recognize(file);
        // return text;

        return new Promise((resolve) => {
            alert(`OCR simulation for ${file.name}.\nIn a real app, this would process the image.`);
            // Simulate some OCR text output based on common bill formats for testing
            let simulatedText = "交易类型：支出\n";
            simulatedText += "商品说明：星巴克咖啡大杯拿铁\n";
            simulatedText += "金额：¥35.00\n";
            simulatedText += `交易时间：${new Date().getFullYear()}-05-20 14:30\n`;
            simulatedText += "支付方式：微信支付\n";
            simulatedText += "收款方：星巴克（上海国金中心店）\n";
            simulatedText += "备注：无";
            
            // To test different scenarios, you can change the simulatedText here or have multiple examples.
            // Example 2: Income
            // simulatedText = "收款成功\n金额：¥500.00\n付款方：张三\n交易时间：2024年05月19日 09:15\n方式：支付宝转账";

            resolve(simulatedText);
        });
    };

    screenshotInput.addEventListener('change', async (event) => {
        const file = event.target.files[0];
        if (file) {
            try {
                // Show some loading state if needed
                billForm.querySelector('.save').textContent = '识别中...';
                billForm.querySelector('.save').disabled = true;

                const ocrText = await performOCR(file); // Call the (simulated) OCR function
                const billData = parseOCRText(ocrText); // Parse the OCR text

                // Populate form fields
                if (billData.amount) document.getElementById('amount').value = billData.amount;
                if (billData.date) document.getElementById('date').value = billData.date;
                if (billData.desc) document.getElementById('desc').value = billData.desc;
                if (billData.category) document.getElementById('category').value = billData.category;
                if (billData.type) document.getElementById('type').value = billData.type;
                if (billData.method) document.getElementById('method').value = billData.method;
                if (billData.note) document.getElementById('note').value = billData.note;
                
                alert('截图信息已部分填充，请检查并补全。');

            } catch (error) {
                console.error('OCR Error:', error);
                alert('截图识别失败，请手动填写。');
            } finally {
                // Reset button state
                billForm.querySelector('.save').textContent = '保存';
                billForm.querySelector('.save').disabled = false;
                screenshotInput.value = ''; // Allow re-uploading the same file if needed
            }
        }
    });
    // ------------- OCR Integration END -------------


    // Function to update summary (basic)
    const updateSummary = () => {
        const currentMonth = new Date().getMonth();
        const currentYear = new Date().getFullYear();

        let monthlyIncome = 0;
        let monthlyExpense = 0;

        bills.forEach(bill => {
            const billDate = new Date(bill.date);
            if (billDate.getFullYear() === currentYear && billDate.getMonth() === currentMonth) {
                if (bill.type === 'income') {
                    monthlyIncome += bill.amount;
                }
                if (bill.type === 'expense') {
                    monthlyExpense += bill.amount;
                }
            }
        });

        const totalExpenseElement = document.querySelector('.stat-card > div:nth-child(2) > div:first-child > div:last-child');
        const avgExpenseElement = document.querySelector('.stat-card > div:nth-child(2) > div:last-child > div:last-child');
        const monthDisplayElement = document.querySelector('.stat-card > div:first-child > div:last-child');
        
        if (totalExpenseElement) {
            totalExpenseElement.textContent = `¥${monthlyExpense.toFixed(2)}`;
        }

        const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
        const today = new Date().getDate();
        // Calculate average expense based on days passed in the current month, or days in month for past months.
        // Ensure divisor is at least 1 to avoid division by zero.
        let daysForAverage = 1;
        const todayFullDate = new Date();
        todayFullDate.setHours(0,0,0,0);

        const firstDayOfMonth = new Date(currentYear, currentMonth, 1);
        
        if (todayFullDate >= firstDayOfMonth) { // if current month or past month
             daysForAverage = (currentYear === todayFullDate.getFullYear() && currentMonth === todayFullDate.getMonth()) ? today : daysInMonth;
        }
        
        const avgExpense = monthlyExpense / (daysForAverage || 1);
        
        if (avgExpenseElement) {
             avgExpenseElement.textContent = `¥${avgExpense.toFixed(2)}`;
        }

        if(monthDisplayElement){
            monthDisplayElement.textContent = `${currentYear} 年 ${currentMonth + 1} 月`;
        }
        
        // console.log(`本月总收入: ¥${monthlyIncome.toFixed(2)}`);
    };

    // Initial render
    renderBills();
});