export const generateReportHtml = (
  stats: any,
  monthStr: string,
  unsubscribeToken: string
) => {
  const { total_seconds, daily_average_seconds, active_days, peak_date, peak_seconds } = stats;

  const formatDuration = (seconds: number) => {
    if (!seconds) return '0 dk';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (h > 0) return `${h} saat ${m} dk`;
    return `${m} dk`;
  };

  return `
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <title>Aylık Çalışma Özeti</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f4f5; margin: 0; padding: 20px; color: #18181b; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
    .header { background-color: #3b82f6; color: #ffffff; padding: 30px 20px; text-align: center; }
    .header h1 { margin: 0; font-size: 24px; font-weight: 600; }
    .content { padding: 30px 20px; }
    .stat-card { background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 15px; margin-bottom: 15px; display: flex; justify-content: space-between; align-items: center; }
    .stat-label { font-size: 14px; color: #64748b; font-weight: 500; }
    .stat-value { font-size: 18px; font-weight: 700; color: #0f172a; }
    .footer { background-color: #f1f5f9; padding: 20px; text-align: center; font-size: 12px; color: #64748b; }
    .footer a { color: #3b82f6; text-decoration: none; }
    .motivate { font-style: italic; color: #3b82f6; text-align: center; margin-top: 20px; font-weight: 500; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Odak Kampı - Aylık Çalışma Raporun</h1>
      <p style="margin: 5px 0 0 0; opacity: 0.9;">${monthStr} Dönemi</p>
    </div>
    <div class="content">
      <p>Merhaba, bu ay Odak Kampı'nda geçirdiğin zamana ait özet verileri aşağıda bulabilirsin. Çalışmalarının karşılığını alman dileğiyle!</p>
      
      <div class="stat-card">
        <div class="stat-label">Toplam Çalışma Süresi</div>
        <div class="stat-value">${formatDuration(total_seconds)}</div>
      </div>
      
      <div class="stat-card">
        <div class="stat-label">Aktif Çalışılan Gün Sayısı</div>
        <div class="stat-value">${active_days} Gün</div>
      </div>
      
      <div class="stat-card">
        <div class="stat-label">Günlük Ortalama Süre</div>
        <div class="stat-value">${formatDuration(daily_average_seconds)}</div>
      </div>
      
      <div class="stat-card">
        <div class="stat-label">En Verimli Gün</div>
        <div class="stat-value">${peak_date || '-'} (${formatDuration(peak_seconds)})</div>
      </div>

      <div class="motivate">
        ${active_days > 15 ? 'Harika bir ay geçirdin! İstikrarın gerçekten takdire şayan. 🚀' : 'Gelecek ay daha fazla odaklanmak için hedeflerini gözden geçirebilirsin. Başarabilirsin! 💪'}
      </div>
    </div>
    <div class="footer">
      <p>Bu e-postayı Odak Kampı uygulamasındaki bildirim ayarların nedeniyle alıyorsun.</p>
      <p><a href="https://app.odakkampi.com/unsubscribe?token=${unsubscribeToken}">Aylık rapor e-postası almaktan vazgeç</a></p>
    </div>
  </div>
</body>
</html>
  `;
};
