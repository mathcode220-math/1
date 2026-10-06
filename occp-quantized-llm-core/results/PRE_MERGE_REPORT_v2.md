# تقرير ما قبل الدمج v2 — بعد تصليح الثغرات

تاريخ: 2026-09-21
الفرع: `210921-fix-pre-merge-gaps`
الترخيص المقصود: CERN-OHL-W

القرار: **يُسمح بالدمج مشروطًا** لمسار INT8 Linear+ReLU (طبقة واحدة وطبقتان مع إعادة تكميم Q24). INT4 والحساب الزائدي وsoftmax خارج الدمج.

لا تخفيض للعتبات.

## ملخص ما تغيّر

- المهمة 1: DistilBERT (q_lin / v_lin / ffn.lin1) INT8، 100 مدخل، seed=42. أقصى خطأ **3.3088%** < 5% → **verified**. SqueezeNet لم يعد دليلًا.
- المهمة 2: الادعاء السابق "INT4 verified" كان تخزين 4-بت وحساب 8-بت. تراكم 3 طبقات × 5 بذور: أسوأ خطأ **26.86%** ≥ 15% → **حذف من مسار العتاد**. RTL في `deprecated/int4_rtl/`.
- المهمة 3: طبقتان على RTL بوحدة واحدة وإعادة تكميم على الشريحة (Q24). INT MAE=0، max_rel **0.2501%**، 24 دورة، `verified_on_rtl: true`. Verilator لا يدعم `$bitstoshortreal`.

## جدول الاختبارات الثمانية (محدَّث)

| # | الاختبار | النتيجة | الدليل |
|---|---|---|---|
| 6 | `get_compression_stats` يستخدم `sum(S**2)` الكامل | verified | `tests/test_quantizer.py` |
| 1 | الزائدي مقابل SVD/INT8 على مهمة Linear | refuted ثم حذف | `results/hyperbolic_verdict.json` |
| 2 | INT8 على طبقات Linear لنموذج لغوي | verified | `results/onnx_test.json` DistilBERT max_rel 3.31% |
| 3 | توسّع RTL N=4/8/16 تطابق بِتّي | verified | `results/rtl_scaling.json` 11/19/35 |
| 5 | طبقتان Linear+ReLU على RTL | verified | `results/multi_layer.json` MAE=0، 0.25%، 24 دورة |
| 4 | INT4 pack/unpack كحساب 4-بت | refuted ثم حذف | `results/int4_accumulation.json` 26.86% |
| 7 | `softmax_core` مقابل numpy | refuted ثم حذف | `results/softmax_test.json` |
| 8 | `make all` من الصفر بعد التصليح | verified | هذا التشغيل: rc=0؛ طبقتان ضمن المسار |

## القرار النهائي

DROP:

- الإسقاط الزائدي SVD+Möbius
- `softmax_core`
- INT4 كمسار حساب (تخزين 4-بت / حساب 8-بت؛ تراكم 26.86%)
- `open_cognitive_top.sv`

KEEP:

- `systolic_array_param` + `relu_activation` عبر `rtl/linear_relu.sv` و`rtl/linear_relu_4x4.sv`
- تكميم INT8 متناظر + انحياز INT32 بمقياس المراكم
- توسّع N=4/8/16
- `rtl/linear_relu_2layer.sv` إعادة تكميم Q24 على الشريحة
- `software/quantizer.py` (إحصاءات الضغط المحلّية)
- إثبات DistilBERT INT8 < 5%

HOLD:

- إعادة تكميم بغير نسبة مُحمَّلة مسبقًا (scale1/scale2 ما زالت تُحسب في Python ثم تُشحن Q24)
- تبليط طبقات 768×768 على المصفوفة 4×4 (DMA / SRAM)
- tokenizer وKV وattention ورأس لغوي

## البوابات العددية (لم تُخفَّض)

- INT8 مقابل FP32: 5%
- INT4 مقابل FP32: نجاح <10%، حذف >15%
- RTL مقابل الذهبي الصحيح: MAE = 0
- طبقتان: نجاح <5%، تحذير تراكم <10%

## قيود صريحة

- لا tokenizer، لا KV cache، لا attention، لا رأس لغوي
- لم يُعدَّل `external/occp` ولا `external/pocket-llm`
- أوزان الاختبار 2: DistilBERT safetensors (ليس SqueezeNet)
- INT4 ليس حسابًا 4-بت
- إعادة التكميم العتادية نسبة صحيحة Q24 وليست IEEE float (Verilator يفسد shortreal)
- طبقتان N=4 فقط على RTL

## توصية نهائية

**يُسمح بالدمج** لوحدات KEEP أعلاه. لا تُدمج INT4 ولا softmax ولا الزائدي. الخطوة التالية بعد الدمج: محرك تبليط يغذّي 4×4 من طبقة DistilBERT كاملة، لا ادّعاء LLM على الشريحة.

## Submodules

- `external/occp` `a9ae3b670d61cc900c3a827cefca6853b0bcf7be`
- `external/pocket-llm` `043f0087f3a7774c5c2c727a805f746753100b47`
