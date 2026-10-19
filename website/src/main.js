// CaRide Official Website – Interactive Logic & Animations
// Inspired by inDrive · Tailored for CaRide Nigeria

document.addEventListener('DOMContentLoaded', () => {

  // ── 1. Navbar Scroll Effect ─────────────────────────────
  const navbar = document.getElementById('navbar');
  if (navbar) {
    const handleScroll = () => {
      navbar.classList.toggle('scrolled', window.scrollY > 24);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();
  }

  // ── 2. Mobile Hamburger Menu ────────────────────────────
  const hamburger = document.getElementById('hamburger');
  const navLinks  = document.getElementById('nav-links');

  if (hamburger && navLinks) {
    hamburger.addEventListener('click', () => {
      const isOpen = navLinks.classList.toggle('open');
      hamburger.classList.toggle('open', isOpen);
      hamburger.setAttribute('aria-expanded', String(isOpen));
    });

    // Close mobile menu when any nav item is clicked
    navLinks.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        navLinks.classList.remove('open');
        hamburger.classList.remove('open');
        hamburger.setAttribute('aria-expanded', 'false');
      });
    });

    // Close on click outside
    document.addEventListener('click', (e) => {
      if (!navbar.contains(e.target) && navLinks.classList.contains('open')) {
        navLinks.classList.remove('open');
        hamburger.classList.remove('open');
        hamburger.setAttribute('aria-expanded', 'false');
      }
    });
  }

  // ── 3. Scroll Reveal Animations ────────────────────────
  const revealElements = document.querySelectorAll('[data-reveal]');
  if (revealElements.length > 0) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('revealed');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

    revealElements.forEach(el => observer.observe(el));
  }

  // ── 4. Stats Counter Animation ──────────────────────────
  const counterElements = document.querySelectorAll('[data-target]');
  if (counterElements.length > 0) {
    const animateCounter = (el) => {
      const target = parseInt(el.dataset.target, 10);
      const suffix = el.dataset.suffix || '';
      const duration = 1800;
      const startTime = performance.now();

      const step = (currentTime) => {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        const easeOutQuad = 1 - (1 - progress) * (1 - progress);
        const currentCount = Math.floor(easeOutQuad * target);

        el.textContent = currentCount.toLocaleString() + suffix;

        if (progress < 1) {
          requestAnimationFrame(step);
        } else {
          el.textContent = target.toLocaleString() + suffix;
        }
      };

      requestAnimationFrame(step);
    };

    const counterObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          animateCounter(entry.target);
          counterObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.4 });

    counterElements.forEach(el => counterObserver.observe(el));
  }

  // ── 5. Hero Interactive Booking Service Switcher ────────
  const heroTabs = document.querySelectorAll('#hero-service-tabs .widget-tab-btn');
  const pickupInput = document.getElementById('pickup-input');
  const dropoffInput = document.getElementById('dropoff-input');
  const fareInput = document.getElementById('fare-input');
  const fareHint = document.getElementById('fare-hint');
  const fareTitle = document.getElementById('fare-offer-title');

  const servicePresets = {
    ride: {
      pickup: 'Victoria Island, Lagos',
      dropoff: 'Ikeja City Mall',
      fare: 3500,
      hint: 'Fair estimate: ₦3,200 – ₦3,800',
      title: 'Your Ride Offer (You Decide)'
    },
    delivery: {
      pickup: 'Surulere, Lagos',
      dropoff: 'Lekki Phase 1',
      fare: 2200,
      hint: 'Courier estimate: ₦1,800 – ₦2,500',
      title: 'Your Delivery Offer'
    },
    intercity: {
      pickup: 'Berger Terminal, Lagos',
      dropoff: 'Ibadan (Bodija Estate)',
      fare: 12500,
      hint: 'Interstate estimate: ₦11,000 – ₦14,000',
      title: 'Intercity Trip Offer'
    },
    rental: {
      pickup: 'Victoria Island, Lagos',
      dropoff: 'Full Day Chauffeur Service',
      fare: 45000,
      hint: 'Daily rental rate: ₦40,000 – ₦55,000',
      title: 'Daily Rental Budget'
    }
  };

  heroTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      heroTabs.forEach(t => t.classList.remove('active', 'tab-ride'));
      tab.classList.add('active', 'tab-ride');

      const service = tab.dataset.service;
      const preset = servicePresets[service];
      if (preset && pickupInput && dropoffInput && fareInput && fareHint) {
        pickupInput.value = preset.pickup;
        dropoffInput.value = preset.dropoff;
        fareInput.value = preset.fare;
        fareHint.textContent = preset.hint;
        if (fareTitle) fareTitle.textContent = preset.title;
      }
    });
  });

  // ── 6. Driver Match Demo Modal Trigger ──────────────────
  const findDriversBtn = document.getElementById('find-drivers-btn');
  const driverMatchModal = document.getElementById('driver-match-modal');
  const closeMatchModal = document.getElementById('close-match-modal');
  const modalOfferDisplay = document.getElementById('modal-offer-display');
  const modalDownloadBtn = document.getElementById('modal-download-btn');

  if (findDriversBtn && driverMatchModal) {
    findDriversBtn.addEventListener('click', () => {
      const currentFare = fareInput ? Number(fareInput.value).toLocaleString() : '3,500';
      if (modalOfferDisplay) {
        modalOfferDisplay.textContent = '₦' + currentFare;
      }
      driverMatchModal.classList.add('open');
    });

    if (closeMatchModal) {
      closeMatchModal.addEventListener('click', () => {
        driverMatchModal.classList.remove('open');
      });
    }

    if (modalDownloadBtn) {
      modalDownloadBtn.addEventListener('click', () => {
        driverMatchModal.classList.remove('open');
      });
    }

    // Modal Accept buttons
    document.querySelectorAll('.modal-accept-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        driverMatchModal.classList.remove('open');
        const downloadSection = document.getElementById('download');
        if (downloadSection) downloadSection.scrollIntoView({ behavior: 'smooth' });
      });
    });
  }

  // ── 7. Driver Registration Modal ────────────────────────
  const driverRegModal = document.getElementById('driver-reg-modal');
  const closeRegModal = document.getElementById('close-reg-modal');
  const driverSignupTrigger = document.getElementById('driver-signup-trigger');
  const navDriverBtn = document.getElementById('nav-driver-btn');
  const calcCtaBtn = document.getElementById('calc-cta-btn');
  const regDownloadAppBtn = document.getElementById('reg-download-app-btn');

  const openDriverModal = () => {
    if (driverRegModal) driverRegModal.classList.add('open');
  };

  if (driverSignupTrigger) driverSignupTrigger.addEventListener('click', openDriverModal);
  if (navDriverBtn) navDriverBtn.addEventListener('click', openDriverModal);
  if (calcCtaBtn) calcCtaBtn.addEventListener('click', openDriverModal);

  if (closeRegModal && driverRegModal) {
    closeRegModal.addEventListener('click', () => {
      driverRegModal.classList.remove('open');
    });
  }

  if (regDownloadAppBtn && driverRegModal) {
    regDownloadAppBtn.addEventListener('click', () => {
      driverRegModal.classList.remove('open');
    });
  }

  // Close modals on overlay backdrop click
  window.addEventListener('click', (e) => {
    if (e.target === driverMatchModal) driverMatchModal.classList.remove('open');
    if (e.target === driverRegModal) driverRegModal.classList.remove('open');
  });

  // Close modals on Escape key
  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (driverMatchModal) driverMatchModal.classList.remove('open');
      if (driverRegModal) driverRegModal.classList.remove('open');
    }
  });

  // ── 8. Driver Earnings Calculator ───────────────────────
  const hoursSlider = document.getElementById('hours-slider');
  const hoursDisplay = document.getElementById('calc-hours-display');
  const earningsDisplay = document.getElementById('calc-earnings-val');
  const calcCarBtn = document.getElementById('calc-car-btn');
  const calcBikeBtn = document.getElementById('calc-bike-btn');

  let currentVehicleMode = 'car'; // 'car' or 'bike'

  const updateEarnings = () => {
    if (!hoursSlider || !earningsDisplay || !hoursDisplay) return;
    const hours = parseInt(hoursSlider.value, 10);
    hoursDisplay.textContent = `${hours} Hours`;

    // Calculation base:
    // Car driver in Nigeria averages ~₦3,000 gross per active hour on CaRide, taking 90% (₦2,700/h).
    // Bike courier averages ~₦1,800 gross per active hour on CaRide, taking 90% (₦1,620/h).
    const hourlyTakeHome = currentVehicleMode === 'car' ? 2750 : 1650;
    const monthlyTotal = Math.round(hours * hourlyTakeHome * 4.2 / 500) * 500;

    earningsDisplay.textContent = monthlyTotal.toLocaleString();
  };

  if (hoursSlider) {
    hoursSlider.addEventListener('input', updateEarnings);
  }

  if (calcCarBtn && calcBikeBtn) {
    calcCarBtn.addEventListener('click', () => {
      calcCarBtn.classList.add('active');
      calcBikeBtn.classList.remove('active');
      currentVehicleMode = 'car';
      updateEarnings();
    });

    calcBikeBtn.addEventListener('click', () => {
      calcBikeBtn.classList.add('active');
      calcCarBtn.classList.remove('active');
      currentVehicleMode = 'bike';
      updateEarnings();
    });
  }

  // Initial calculation run
  updateEarnings();

  // ── 9. FAQ Accordion ────────────────────────────────────
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const wasOpen = item.classList.contains('open');

        // Close other accordion items
        faqItems.forEach(i => i.classList.remove('open'));

        // Toggle this item
        if (!wasOpen) {
          item.classList.add('open');
        }
      });
    }
  });

  // ── 10. Table of Contents Observer (Legal Pages) ────────
  const tocLinks = document.querySelectorAll('#toc-list a');
  if (tocLinks.length > 0) {
    const sections = document.querySelectorAll('[id]');
    const tocObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          tocLinks.forEach(l => l.classList.remove('active'));
          const activeLink = document.querySelector(`#toc-list a[href="#${entry.target.id}"]`);
          if (activeLink) activeLink.classList.add('active');
        }
      });
    }, { rootMargin: '-80px 0px -60% 0px' });

    sections.forEach(s => tocObserver.observe(s));
  }

});
