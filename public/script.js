document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('add-product-form');
  const messageDiv = document.getElementById('form-message');
  const productsContainer = document.getElementById('products-container');
  
  // モーダル関連の要素
  const editModal = document.getElementById('edit-modal');
  const editForm = document.getElementById('edit-product-form');
  const cancelEditBtn = document.getElementById('cancel-edit');

  const bulkModal = document.getElementById('bulk-modal');
  const btnOpenBulk = document.getElementById('btn-open-bulk');
  const cancelBulkBtn = document.getElementById('cancel-bulk');
  const bulkForm = document.getElementById('bulk-form');
  const bulkMessage = document.getElementById('bulk-message');

  // 設定モーダル関連
  const settingsModal = document.getElementById('settings-modal');
  const btnOpenSettings = document.getElementById('btn-open-settings');
  const cancelSettingsBtn = document.getElementById('cancel-settings');
  const settingsForm = document.getElementById('settings-form');
  const webhookUrlInput = document.getElementById('webhook-url');
  const settingsMessage = document.getElementById('settings-message');
  const btnBulkUpdateTargets = document.getElementById('btn-bulk-update-targets');
  const bulkUpdateMessage = document.getElementById('bulk-update-message');

  // 詳細モーダル関連
  const detailModal = document.getElementById('detail-modal');
  const closeDetailBtn = document.getElementById('close-detail');
  const detailTitle = document.getElementById('detail-title');
  let currentDetailProduct = null;
  let detailChartInstance = null;

  // 取得した全商品データとチャートのインスタンスを保持
  let allProducts = [];
  let currentChartRange = 'all'; // 'all', '1w', '1m', '1y'
  let currentViewMode = 'grid'; // 'grid', 'list'
  let currentSortMode = 'discount-desc';

  // 商品リストの取得と描画
  async function fetchAndRenderProducts() {
    try {
      const response = await fetch('/api/products');
      allProducts = await response.json();

      if (allProducts.length === 0) {
        productsContainer.innerHTML = '<div class="loading-spinner">登録された商品がありません。</div>';
        return;
      }

      applySorting();
      renderCards();
    } catch (error) {
      console.error('Error fetching products:', error);
      productsContainer.innerHTML = '<div class="loading-spinner">データの取得に失敗しました。</div>';
    }
  }

  // ソートの適用
  function applySorting() {
    allProducts.sort((a, b) => {
      switch (currentSortMode) {
        case 'discount-desc':
          return (b.discount_rate || 0) - (a.discount_rate || 0);
        case 'discount-asc':
          return (a.discount_rate || 0) - (b.discount_rate || 0);
        case 'price-asc':
          return (a.latest_price || 0) - (b.latest_price || 0);
        case 'price-desc':
          return (b.latest_price || 0) - (a.latest_price || 0);
        case 'date-desc':
          return b.id - a.id;
        case 'date-asc':
          return a.id - b.id;
        default:
          return (b.discount_rate || 0) - (a.discount_rate || 0);
      }
    });
  }

  // グラフ用データの間引きとフィルタリング関数
  function filterChartData(data, range) {
    if (!data || data.length === 0) return { labels: [], dataset: [] };
    
    let cutoffDate = new Date(0); // 過去すべて
    const now = new Date();
    
    if (range === '1w') {
      cutoffDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    } else if (range === '1m') {
      cutoffDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    } else if (range === '1y') {
      cutoffDate = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
    }

    const filtered = data.filter(item => new Date(item.x) >= cutoffDate);
    
    // 間引き処理 (データが多すぎる場合、最大200点程度に間引く)
    let thinned = filtered;
    if (thinned.length > 200) {
      const step = Math.ceil(thinned.length / 200);
      thinned = thinned.filter((_, i) => i % step === 0 || i === thinned.length - 1);
    }

    return {
      labels: thinned.map(d => d.label),
      dataset: thinned.map(d => d.y)
    };
  }

  // 商品カードの描画
  function renderCards() {
    productsContainer.innerHTML = ''; // クリア

    allProducts.forEach((product, index) => {
      // 在庫バッジのクラス判定
      let badgeClass = 'stock-error';
      if (product.stock_status.includes('在庫あり')) {
        badgeClass = 'stock-ok';
      } else if (product.stock_status.includes('お取り寄せ')) {
        badgeClass = 'stock-warn';
      }

      const card = document.createElement('div');
      card.className = 'card product-card glass-panel';
      card.style.animationDelay = `${index * 0.1}s`; // 順にふわっと表示させる

      const priceDisplay = product.latest_price ? `${product.latest_price.toLocaleString()}円` : 'データ取得待ち';
      const updatedDisplay = product.updated_at ? `更新: ${product.updated_at}` : 'まだ取得されていません';
      const discountDisplay = product.discount_rate > 0 ? `<span style="color: var(--danger-color); font-weight: bold; font-size: 0.9em; margin-left: 0.5rem;">(${product.discount_rate}% OFF)</span>` : '';

      card.innerHTML = `
        <div class="card-actions">
          <button class="btn-icon btn-detail" data-id="${product.id}" title="グラフを見る">📊</button>
          <button class="btn-icon btn-scrape" data-id="${product.id}" title="今すぐ価格を取得">🔄</button>
          <button class="btn-icon btn-edit" data-id="${product.id}" data-name="${product.name}" data-target="${product.target_price}" title="編集">✏️</button>
          <button class="btn-danger btn-delete" data-id="${product.id}" title="削除">削除</button>
        </div>
        <div class="product-header">
          <span class="badge ${badgeClass}">${product.stock_status || '情報なし'}</span>
          <h3 class="product-title">${product.name}</h3>
          <a href="${product.url}" target="_blank" class="product-url">ヨドバシで見る ↗</a>
        </div>
        <div class="product-stats">
          <div class="stat-item">
            <span class="stat-label">現在の実質価格</span>
            <span class="stat-value">${priceDisplay}${discountDisplay}</span>
          </div>
          <div class="stat-item" style="text-align: right;">
            <span class="stat-label">目標価格</span>
            <span class="stat-value" style="font-size: 1rem; color: var(--text-secondary);">${product.target_price.toLocaleString()}円</span>
            <span class="stat-label" style="margin-top: 0.5rem; text-transform: none;">${updatedDisplay}</span>
          </div>
        </div>
      `;

      productsContainer.appendChild(card);
    });
  }

  // 詳細モーダルでのチャート描画
  function renderChart(product) {
    if (!product) return;
    const canvas = document.getElementById('detail-chart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');

    // 既存のチャートがあれば破棄
    if (detailChartInstance) {
      detailChartInstance.destroy();
    }

    if (product.chart_data && product.chart_data.length > 0) {
      const filteredData = filterChartData(product.chart_data, currentChartRange);
      
      const gradient = ctx.createLinearGradient(0, 0, 0, 400);
      gradient.addColorStop(0, 'rgba(230, 0, 18, 0.3)');
      gradient.addColorStop(1, 'rgba(230, 0, 18, 0.0)');

      detailChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
          labels: filteredData.labels,
          datasets: [{
            label: '実質価格 (円)',
            data: filteredData.dataset,
                borderColor: '#3b82f6',
                backgroundColor: gradient,
                borderWidth: 2,
                pointBackgroundColor: '#fff',
                pointBorderColor: '#3b82f6',
                pointRadius: 4,
                pointHoverRadius: 6,
                fill: true,
                tension: 0.4 // 少し丸みを帯びた線
              }]
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              plugins: {
                legend: { display: false },
                tooltip: {
                  backgroundColor: 'rgba(15, 23, 42, 0.9)',
                  titleColor: '#f8fafc',
                  bodyColor: '#e2e8f0',
                  padding: 10,
                  cornerRadius: 8,
                  displayColors: false
                }
              },
              scales: {
                x: {
                  grid: { color: 'rgba(255, 255, 255, 0.05)' },
                  ticks: { color: '#94a3b8' }
                },
                y: {
                  grid: { color: 'rgba(255, 255, 255, 0.05)' },
                  ticks: { color: '#94a3b8' },
                  beginAtZero: false // 価格の変動を見やすくするため
                }
              }
            }
          });
        } else {
          ctx.font = '16px Inter';
          ctx.fillStyle = '#94a3b8';
          ctx.textAlign = 'center';
          ctx.fillText('まだ価格データがありません', canvas.width / 2, canvas.height / 2);
        }
  }

  // 詳細モーダルのイベント制御
  productsContainer.addEventListener('click', (e) => {
    // グラフ詳細ボタン
    if (e.target.closest('.btn-detail')) {
      const id = parseInt(e.target.closest('.btn-detail').getAttribute('data-id'));
      const product = allProducts.find(p => p.id === id);
      if (product) {
        currentDetailProduct = product;
        detailTitle.innerText = product.name;
        detailModal.classList.remove('hidden');
        renderChart(product);
      }
    }
  });

  closeDetailBtn.addEventListener('click', () => {
    detailModal.classList.add('hidden');
  });

  // 期間フィルタボタンのイベントリスナー (モーダル内)
  document.querySelectorAll('.chart-filters .btn-filter').forEach(btn => {
    btn.addEventListener('click', (e) => {
      document.querySelectorAll('.chart-filters .btn-filter').forEach(b => b.classList.remove('active'));
      e.target.classList.add('active');
      currentChartRange = e.target.getAttribute('data-range');
      if (currentDetailProduct) {
        renderChart(currentDetailProduct);
      }
    });
  });

  // 表示モード切り替えボタンのイベントリスナー
  document.querySelectorAll('.view-toggles .btn-filter').forEach(btn => {
    btn.addEventListener('click', (e) => {
      document.querySelectorAll('.view-toggles .btn-filter').forEach(b => b.classList.remove('active'));
      e.target.classList.add('active');
      currentViewMode = e.target.getAttribute('data-view');
      productsContainer.className = currentViewMode === 'list' ? 'products-list' : 'products-grid';
    });
  });

  // ===== 設定モーダルの処理 =====
  btnOpenSettings.addEventListener('click', async () => {
    settingsModal.classList.remove('hidden');
    settingsMessage.className = 'hidden';
    settingsMessage.innerText = '';
    bulkUpdateMessage.className = 'hidden';
    bulkUpdateMessage.innerText = '';
    
    // 現在の設定を取得してフォームにセット
    try {
      const res = await fetch('/api/settings');
      const data = await res.json();
      webhookUrlInput.value = data.discord_webhook_url || '';
    } catch (e) {
      console.error(e);
    }
  });

  cancelSettingsBtn.addEventListener('click', () => {
    settingsModal.classList.add('hidden');
  });

  // 目標価格一括更新ボタンの処理
  btnBulkUpdateTargets.addEventListener('click', async () => {
    if (!confirm('全商品の目標価格を現在の価格の10%OFFで一括上書きします。よろしいですか？')) return;
    
    const originalText = btnBulkUpdateTargets.innerText;
    btnBulkUpdateTargets.innerText = '更新中...';
    btnBulkUpdateTargets.disabled = true;

    try {
      const res = await fetch('/api/products/bulk_update_targets', { method: 'POST' });
      const data = await res.json();
      
      bulkUpdateMessage.className = 'msg-success';
      bulkUpdateMessage.style.display = 'block';
      bulkUpdateMessage.innerText = data.message || '一括更新が完了しました。';
      
      // データ再取得
      fetchAndRenderProducts();
    } catch (err) {
      bulkUpdateMessage.className = 'msg-error';
      bulkUpdateMessage.style.display = 'block';
      bulkUpdateMessage.innerText = 'エラーが発生しました';
    } finally {
      btnBulkUpdateTargets.innerText = originalText;
      btnBulkUpdateTargets.disabled = false;
    }
  });

  settingsForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const submitBtn = settingsForm.querySelector('button[type="submit"]');
    const originalText = submitBtn.innerText;
    submitBtn.innerText = '保存中...';
    submitBtn.disabled = true;

    try {
      const res = await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ discord_webhook_url: webhookUrlInput.value.trim() })
      });
      const data = await res.json();
      
      settingsMessage.className = 'msg-success';
      settingsMessage.style.display = 'block';
      settingsMessage.innerText = data.message || '保存しました。';
      
      setTimeout(() => {
        settingsModal.classList.add('hidden');
      }, 1500);
    } catch (err) {
      settingsMessage.className = 'msg-error';
      settingsMessage.style.display = 'block';
      settingsMessage.innerText = 'エラーが発生しました';
    } finally {
      submitBtn.innerText = originalText;
      submitBtn.disabled = false;
    }
  });

  // ソートセレクトのイベントリスナー
  document.getElementById('sort-select').addEventListener('change', (e) => {
    currentSortMode = e.target.value;
    applySorting();
    renderCards();
  });

  // 商品登録フォームの送信処理 (JavaのAjax/Fetchと同じです)
  form.addEventListener('submit', async (e) => {
    e.preventDefault(); // デフォルトのフォーム送信(ページリロード)を無効化
    
    const formData = {
      name: document.getElementById('name').value,
      url: document.getElementById('url').value,
      target_price: document.getElementById('target_price').value
    };

    const submitBtn = form.querySelector('button');
    const originalBtnText = submitBtn.innerText;
    submitBtn.innerText = '登録中...';
    submitBtn.disabled = true;

    try {
      const response = await fetch('/api/products', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(formData)
      });

      if (response.ok) {
        messageDiv.className = 'msg-success';
        messageDiv.innerText = '✅ 商品を登録しました！';
        form.reset();
        
        // リストを再取得して画面を更新
        fetchAndRenderProducts();
      } else {
        const errorData = await response.json();
        messageDiv.className = 'msg-error';
        messageDiv.innerText = `❌ エラー: ${errorData.error || '登録に失敗しました'}`;
      }
    } catch (error) {
      messageDiv.className = 'msg-error';
      messageDiv.innerText = '❌ ネットワークエラーが発生しました';
    } finally {
      submitBtn.innerText = originalBtnText;
      submitBtn.disabled = false;
      
      // 3秒後にメッセージを消す
      setTimeout(() => {
        messageDiv.className = 'hidden';
      }, 3000);
    }
  });

  // 初回読み込み時のデータ取得
  fetchAndRenderProducts();

  // ----- 新規追加機能のイベントリスナー -----

  // 編集モーダルを閉じる
  cancelEditBtn.addEventListener('click', () => {
    editModal.classList.add('hidden');
  });

  // モーダル外をクリックで閉じる
  editModal.addEventListener('click', (e) => {
    if (e.target === editModal) {
      editModal.classList.add('hidden');
    }
  });

  // 編集フォームの送信 (PUTリクエスト)
  editForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = document.getElementById('edit-id').value;
    const name = document.getElementById('edit-name').value;
    const targetPrice = document.getElementById('edit-target_price').value;

    const submitBtn = editForm.querySelector('button[type="submit"]');
    const originalText = submitBtn.innerText;
    submitBtn.innerText = '保存中...';
    submitBtn.disabled = true;

    try {
      const response = await fetch(`/api/products/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, target_price: targetPrice })
      });
      if (response.ok) {
        editModal.classList.add('hidden');
        fetchAndRenderProducts();
      } else {
        alert('編集に失敗しました');
      }
    } catch (err) {
      alert('通信エラーが発生しました');
    } finally {
      submitBtn.innerText = originalText;
      submitBtn.disabled = false;
    }
  });

  // イベントデリゲーション (動的に追加されたカード内のボタンを一括でハンドリング)
  productsContainer.addEventListener('click', async (e) => {
    const target = e.target;

    // --- 削除ボタンの処理 ---
    if (target.classList.contains('btn-delete')) {
      const id = target.getAttribute('data-id');
      if (confirm('本当にこの商品を削除しますか？')) {
        target.disabled = true;
        target.innerText = '...';
        try {
          const res = await fetch(`/api/products/${id}`, { method: 'DELETE' });
          if (res.ok) {
            fetchAndRenderProducts();
          } else {
            alert('削除に失敗しました');
            target.disabled = false;
            target.innerText = '削除';
          }
        } catch (err) {
          alert('通信エラー');
        }
      }
    }

    // --- 編集ボタンの処理 ---
    if (target.classList.contains('btn-edit')) {
      const id = target.getAttribute('data-id');
      const name = target.getAttribute('data-name');
      const targetPrice = target.getAttribute('data-target');

      document.getElementById('edit-id').value = id;
      document.getElementById('edit-name').value = name;
      document.getElementById('edit-target_price').value = targetPrice;

      editModal.classList.remove('hidden');
    }

    // --- 今すぐ更新ボタンの処理 ---
    if (target.classList.contains('btn-scrape')) {
      const id = target.getAttribute('data-id');
      
      // ボタンをぐるぐる回すアニメーション風にする
      target.disabled = true;
      target.style.transform = 'rotate(180deg)';
      target.style.transition = 'transform 1s ease';
      target.style.opacity = '0.5';

      try {
        const res = await fetch(`/api/products/${id}/scrape`, { method: 'POST' });
        if (res.ok) {
          // 更新成功したらリストを再描画
          fetchAndRenderProducts();
        } else {
          const err = await res.json();
          alert(`更新に失敗しました: ${err.error || ''}`);
        }
      } catch (err) {
        alert('通信エラーが発生しました');
      } finally {
        target.disabled = false;
        target.style.transform = 'rotate(0deg)';
        target.style.opacity = '1';
      }
    }
  });

  // --- 一括登録機能の処理 ---
  btnOpenBulk.addEventListener('click', () => {
    bulkModal.classList.remove('hidden');
    bulkMessage.classList.add('hidden');
    document.getElementById('bulk-urls').value = '';
  });

  cancelBulkBtn.addEventListener('click', () => {
    bulkModal.classList.add('hidden');
  });

  bulkModal.addEventListener('click', (e) => {
    if (e.target === bulkModal) {
      bulkModal.classList.add('hidden');
    }
  });

  bulkForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const urlsText = document.getElementById('bulk-urls').value;
    // URLを改行で分割
    const urls = urlsText.split('\n').map(u => u.trim()).filter(u => u !== '');

    if (urls.length === 0) {
      alert('URLを入力してください');
      return;
    }

    const submitBtn = bulkForm.querySelector('button[type="submit"]');
    const originalText = submitBtn.innerText;
    submitBtn.innerText = '送信中...';
    submitBtn.disabled = true;
    bulkMessage.classList.add('hidden');

    try {
      const response = await fetch('/api/products/bulk', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ urls })
      });

      const resData = await response.json();

      if (response.ok || response.status === 202) {
        bulkMessage.className = 'msg-success';
        bulkMessage.innerText = resData.message || '一括登録のリクエストを受け付けました。';
        document.getElementById('bulk-urls').value = '';
        
        // 少し待ってからモーダルを閉じ、リストを更新
        setTimeout(() => {
          bulkModal.classList.add('hidden');
          fetchAndRenderProducts();
        }, 2000);
      } else {
        bulkMessage.className = 'msg-error';
        bulkMessage.innerText = resData.error || 'エラーが発生しました';
      }
    } catch (err) {
      bulkMessage.className = 'msg-error';
      bulkMessage.innerText = '通信エラーが発生しました';
    } finally {
      submitBtn.innerText = originalText;
      submitBtn.disabled = false;
    }
  });
});
