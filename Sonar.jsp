
<%@ page contentType="text/html; charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Front Sonar (Slow Scan • Optical Detail)</title>
  <style>
    body { margin: 0; background: #000; color: #9fe8ff; font: 14px/1.35 Arial, sans-serif; }
    .wrap { max-width: 960px; margin: 14px auto; padding: 0 8px; }
    .head { color: #9fe8ff; text-align: center; margin-bottom: 8px; opacity: .9; }
    canvas { display: block; width: 100%; height: auto; background: #000; border: 1px solid #134; border-radius: 4px; }
    .legend { text-align:center; color:#8cd6ff; font-size:12px; margin-top:6px; opacity:.8; }
    .dot { display:inline-block; width:10px; height:10px; border-radius:50%; margin-right:6px; vertical-align:middle; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="head">Front-Looking Sonar • Optical Only • 200–800 m</div>
    <canvas id="sonar" width="960" height="520"></canvas>
    <div class="legend">
      <span class="dot" style="background:#ff4d4d"></span>Very Low
      <span class="dot" style="background:#ff944d; margin-left:14px;"></span>Low
      <span class="dot" style="background:#ffd24d; margin-left:14px;"></span>Medium
      <span class="dot" style="background:#9cff4d; margin-left:14px;"></span>High
      <span class="dot" style="background:#2bff88; margin-left:14px;"></span>Very High
    </div>
  </div>

  <script>
    const canvas = document.getElementById('sonar');
    const ctx = canvas.getContext('2d');

    // Tweak yahan se:
    const MIN_RANGE = 200;       // meters
    const MAX_RANGE = 800;       // meters
    const RANGES = [200, 400, 600, 800];
    const FOV = 120;             // forward arc (±60°)
    const BEAM_SPEED = 0.35;     // deg per frame (slow). Aur slow chahiye to 0.2 try karein.
    const BEAM_WIDTH = 8;        // beam detection width (degrees)

    // Layout
    const cx = canvas.width / 2;
    const cy = canvas.height - 28;
    const maxRadius = Math.min(canvas.width * 0.48, canvas.height - 80);

    // Helpers
    const clamp = (v,a,b)=>Math.max(a,Math.min(b,v));
    const toRad = deg => (deg - 90) * Math.PI / 180;
    const polar = (angDeg, dist) => {
      const r = (dist / MAX_RANGE) * maxRadius;
      const a = toRad(angDeg);
      return { x: cx + r * Math.cos(a), y: cy + r * Math.sin(a) };
    };

    // Optical scoring (distance ke hisaab se realistic)
    function opticalScore(distance){
      // Close = better. 200m -> ~90+, 800m -> ~45
      const t = (distance - MIN_RANGE) / (MAX_RANGE - MIN_RANGE); // 0..1
      const base = 90 - t * 45; // 90 to 45
      const noise = (Math.random() - 0.5) * 6; // slight jitter
      return clamp(Math.round(base + noise), 10, 99);
    }

    function levelFromScore(score){
      if (score >= 88) return {name:'Very High', color:'#2bff88', seg:5};
      if (score >= 74) return {name:'High',      color:'#9cff4d', seg:4};
      if (score >= 60) return {name:'Medium',    color:'#ffd24d', seg:3};
      if (score >= 46) return {name:'Low',       color:'#ff944d', seg:2};
      return                {name:'Very Low',    color:'#ff4d4d', seg:1};
    }

    // Targets (no speed display, sirf halka drift)
    let targets = [];
    function newTarget(id){
      return {
        id,
        angle: (Math.random() * (FOV - 16)) - (FOV/2 - 8),
        distance: MIN_RANGE + Math.random() * (MAX_RANGE - MIN_RANGE),
        size: 7 + Math.random() * 5,
        driftA: (Math.random() - 0.5) * 0.06,
        driftD: (Math.random() - 0.5) * 0.4
      };
    }
    function initTargets(){
      targets = [];
      const n = 5 + Math.floor(Math.random() * 3); // 5–7 targets
      for (let i=0;i<n;i++) targets.push(newTarget(100+i));
    }

    // Draw parts
    function drawBackgroundWedge(){
      const a1 = toRad(-FOV/2), a2 = toRad(+FOV/2);
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, maxRadius, a1, a2, false);
      ctx.closePath();

      const g = ctx.createRadialGradient(cx, cy, maxRadius * 0.15, cx, cy, maxRadius);
      g.addColorStop(0.00, 'rgba(0,70,140,0.92)');
      g.addColorStop(0.60, 'rgba(0,55,110,0.94)');
      g.addColorStop(1.00, 'rgba(0,35,75,0.96)');
      ctx.fillStyle = g;
      ctx.fill();
      ctx.restore();
    }

    function drawRangeArcs(){
      const a1 = toRad(-FOV/2), a2 = toRad(+FOV/2);
      ctx.strokeStyle = 'rgba(255,255,255,0.6)';
      ctx.lineWidth = 1.4;

      RANGES.forEach(m=>{
        const r = (m / MAX_RANGE) * maxRadius;
        ctx.beginPath();
        ctx.arc(cx, cy, r, a1, a2, false);
        ctx.stroke();

        // labels
        ctx.fillStyle = '#ffe066';
        ctx.font = '12px Arial';
        const pL = { x: cx + r * Math.cos(a1), y: cy + r * Math.sin(a1) };
        const pR = { x: cx + r * Math.cos(a2), y: cy + r * Math.sin(a2) };
        ctx.fillText(`${m} m`, pL.x - 22, pL.y - 6);
        ctx.fillText(`${m} m`, pR.x + 6,  pR.y - 6);
      });

      // centerline 0°
      ctx.beginPath();
      const pTop = polar(0, MAX_RANGE);
      ctx.moveTo(cx, cy);
      ctx.lineTo(pTop.x, pTop.y);
      ctx.lineWidth = 2;
      ctx.strokeStyle = '#ffffff';
      ctx.stroke();

      ctx.fillStyle = '#ffffff';
      ctx.font = '12px Arial';
      ctx.fillText('0°', pTop.x - 8, pTop.y - 8);
    }

    let beamAngle = -FOV/2;
    function drawScanBeam(){
      const start = beamAngle - BEAM_WIDTH/2;
      const end   = beamAngle + BEAM_WIDTH/2;

      // soft sector
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, maxRadius, toRad(start), toRad(end), false);
      ctx.closePath();
      const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, maxRadius);
      grad.addColorStop(0, 'rgba(0,255,255,0.09)');
      grad.addColorStop(1, 'rgba(0,255,255,0.0)');
      ctx.fillStyle = grad;
      ctx.fill();

      // center scan line
      ctx.beginPath();
      const mid = toRad(beamAngle);
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx + maxRadius * Math.cos(mid), cy + maxRadius * Math.sin(mid));
      ctx.strokeStyle = '#9ff';
      ctx.lineWidth = 2;
      ctx.shadowBlur = 10;
      ctx.shadowColor = '#9ff';
      ctx.stroke();
      ctx.shadowBlur = 0;
      ctx.restore();

      beamAngle += BEAM_SPEED;
      if (beamAngle > FOV/2) beamAngle = -FOV/2;
    }

    function drawOpticalBar(x, y, level){
      // 5 tiny segments bar
      const segW = 6, segH = 10, gap = 2;
      for (let i=0;i<5;i++){
        ctx.beginPath();
        ctx.rect(x + i*(segW+gap), y, segW, segH);
        ctx.fillStyle = i < level.seg ? level.color : 'rgba(255,255,255,0.16)';
        ctx.strokeStyle = 'rgba(255,255,255,0.25)';
        ctx.lineWidth = 0.6;
        ctx.fill(); ctx.stroke();
      }
    }

    function drawTargets(){
      // clip to wedge
      ctx.save();
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, maxRadius, toRad(-FOV/2), toRad(+FOV/2), false);
      ctx.closePath();
      ctx.clip();

      targets.forEach(t=>{
        // very light drift (no speed shown)
        t.angle += t.driftA;
        t.distance += t.driftD;
        if (Math.random() < 0.02) t.driftA *= -1;
        if (Math.random() < 0.02) t.driftD *= -1;
        t.angle = clamp(t.angle, -FOV/2 + 5, FOV/2 - 5);
        t.distance = clamp(t.distance, MIN_RANGE, MAX_RANGE);

        const p = polar(t.angle, t.distance);

        // detection check
        const detected = Math.abs(beamAngle - t.angle) < BEAM_WIDTH/2;

        // optical calc (dynamic by distance)
        const score = opticalScore(t.distance);
        const level = levelFromScore(score);

        // base dot (faint if not in beam)
        ctx.beginPath();
        ctx.arc(p.x, p.y, t.size * (detected ? 1.15 : 0.9), 0, Math.PI * 2);
        ctx.fillStyle = detected ? level.color : 'rgba(180,220,255,0.30)';
        ctx.fill();

        if (detected){
          // glow ring
          ctx.beginPath();
          ctx.arc(p.x, p.y, t.size + 4, 0, Math.PI * 2);
          ctx.strokeStyle = level.color + '99';
          ctx.lineWidth = 1.2;
          ctx.stroke();

          // labels
          ctx.fillStyle = '#ffffff';
          ctx.font = '11px Arial';
          ctx.fillText(`${Math.round(t.distance)} m`, p.x + 12, p.y - 4);

          // optical percent + level
          ctx.fillStyle = level.color;
          ctx.fillText(`Optical ${score}% (${level.name})`, p.x + 12, p.y + 10);

          // 5-seg mini bar
          drawOpticalBar(p.x + 12, p.y + 16, level);
        }
      });

      ctx.restore();
    }

    function drawSonarHead(){
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx - 10, cy - 14);
      ctx.lineTo(cx + 10, cy - 14);
      ctx.closePath();
      ctx.fillStyle = '#fff';
      ctx.fill();
      ctx.strokeStyle = '#555';
      ctx.stroke();
    }

    function draw(){
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      drawBackgroundWedge();
      drawRangeArcs();
      drawTargets();
      drawScanBeam();
      drawSonarHead();
    }

    function loop(){
      draw();
      requestAnimationFrame(loop);
    }

    // Init
    initTargets();
    loop();
    setInterval(initTargets, 14000); // refresh targets slowly
  </script>
</body>
</html>
