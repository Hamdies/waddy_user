// The deal, in one place. Every brochure edition reads its commercial terms
// and contact details from here, in English and Arabic.
//
// A value left as null prints as an amber [placeholder]. Fill one in as
// { en: '…', ar: '…' } and rebuild:  node build.js && python3 make_pptx.py
//
// Confirmed by Waddy (2026-11-12): partnership is non-exclusive; founding
// partners pay no setup fee and get a reduced launch commission. Rates,
// delivery fee, settlement, refunds and exit are agreed in the room and are
// deliberately NOT printed; only monthlyFee and the contacts reach the page.
module.exports = {
  commission: null,        // e.g. { en: '18%', ar: '18%' }: standard rate per completed order
  launchCommission: null,  // e.g. { en: '10%', ar: '10%' }: founding-partner rate
  launchPeriod: null,      // e.g. { en: '3 months', ar: '3 أشهر' }
  monthlyFee: null,        // e.g. { en: 'None', ar: 'لا يوجد' }
  deliveryFee: null,       // e.g. { en: 'Paid by the customer', ar: 'يدفعها العميل' }
  settlement: null,        // e.g. { en: 'Weekly, every Sunday, by bank transfer', ar: 'أسبوعيًا كل أحد بتحويل بنكي' }
  refunds: null,           // who bears the cost of a refund, by cause
  contract: null,          // e.g. { en: 'Monthly, cancel with 14 days’ notice', ar: 'شهري، والإلغاء بإشعار قبل 14 يومًا' }

  // Contact. whatsapp also becomes the QR code on the join page (wa.me link).
  whatsapp: null,          // e.g. { en: '+20 100 000 0000', ar: '+20 100 000 0000' }
  phone: null,
  email: null,
};
