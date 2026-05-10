const header = document.querySelector(".site-header");
const canvas = document.querySelector("#heroCanvas");
const ctx = canvas.getContext("2d");
const toast = document.querySelector(".toast");
let width = 0;
let height = 0;
let rafId = 0;
let toastTimer = 0;

function resizeCanvas() {
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  const box = canvas.getBoundingClientRect();
  width = Math.max(1, Math.floor(box.width));
  height = Math.max(1, Math.floor(box.height));
  canvas.width = Math.floor(width * ratio);
  canvas.height = Math.floor(height * ratio);
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
}

function drawHero(time) {
  ctx.clearRect(0, 0, width, height);

  const softBlue = ctx.createRadialGradient(
    width * 0.72,
    height * 0.28,
    20,
    width * 0.72,
    height * 0.28,
    Math.max(width, height) * 0.52,
  );
  softBlue.addColorStop(0, "rgba(24, 185, 230, 0.18)");
  softBlue.addColorStop(1, "rgba(24, 185, 230, 0)");
  ctx.fillStyle = softBlue;
  ctx.fillRect(0, 0, width, height);

  const softPink = ctx.createRadialGradient(
    width * 0.88,
    height * 0.82,
    20,
    width * 0.88,
    height * 0.82,
    Math.max(width, height) * 0.42,
  );
  softPink.addColorStop(0, "rgba(242, 188, 200, 0.22)");
  softPink.addColorStop(1, "rgba(242, 188, 200, 0)");
  ctx.fillStyle = softPink;
  ctx.fillRect(0, 0, width, height);

  const baseY = height * 0.58;
  const waveWidth = Math.max(width, 720);
  ctx.lineWidth = 1.5;

  for (let layer = 0; layer < 3; layer += 1) {
    ctx.beginPath();
    const amp = 12 + layer * 8;
    const freq = 0.012 - layer * 0.002;
    const speed = time * (0.00045 + layer * 0.00016);
    for (let x = -20; x <= waveWidth + 20; x += 8) {
      const y =
        baseY +
        Math.sin(x * freq + speed * 3.2) * amp +
        Math.cos(x * freq * 0.68 + speed) * (amp * 0.45) +
        layer * 24;
      if (x === -20) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.strokeStyle = `rgba(3, 153, 208, ${0.16 - layer * 0.035})`;
    ctx.stroke();
  }

  for (let i = 0; i < 22; i += 1) {
    const x = ((i * 97 + time * 0.012) % (width + 120)) - 60;
    const y = height * (0.18 + ((i * 37) % 58) / 100);
    const radius = 1.5 + (i % 4) * 0.55;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fillStyle = i % 3 === 0 ? "rgba(3,153,208,.22)" : "rgba(123,135,148,.18)";
    ctx.fill();
  }

  rafId = requestAnimationFrame(drawHero);
}

function showToast(message) {
  window.clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.add("show");
  toastTimer = window.setTimeout(() => {
    toast.classList.remove("show");
  }, 2600);
}

function initReveal() {
  const items = document.querySelectorAll(".reveal");
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12 },
  );
  items.forEach((item) => observer.observe(item));
}

function bindDownloads() {
  document.querySelectorAll("[data-download]").forEach((button) => {
    button.addEventListener("click", () => {
      const name = button.getAttribute("data-download");
      if (button.tagName.toLowerCase() === "a") {
        showToast(`${name} 正在打开。`);
        return;
      }
      showToast(`${name} 正在准备中。`);
    });
  });
}

function bindHeader() {
  const update = () => {
    header.dataset.elevated = window.scrollY > 12 ? "true" : "false";
  };
  update();
  window.addEventListener("scroll", update, { passive: true });
}

window.addEventListener("resize", resizeCanvas, { passive: true });
window.addEventListener("load", () => {
  resizeCanvas();
  initReveal();
  bindDownloads();
  bindHeader();
  rafId = requestAnimationFrame(drawHero);
});

window.addEventListener("beforeunload", () => {
  cancelAnimationFrame(rafId);
});
