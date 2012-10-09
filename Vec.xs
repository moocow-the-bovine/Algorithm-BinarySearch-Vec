/*-*- Mode: C -*- */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
/*#include "ppport.h"*/

#ifndef uint
typedef unsigned int  uint;
#endif

#ifndef uchar
typedef unsigned char uchar;
#endif

const uint KEY_NOT_FOUND = (uint)-1;

/*==============================================================================
 * Utils
 */

//--------------------------------------------------------------
static inline int absv_cmp(unsigned int a, unsigned int b)
{
  if      (a<b) return -1;
  else if (a>b) return  1;
  return 0;
}

//--------------------------------------------------------------
static inline uint absv_vget(const uchar *v, uint i, uint nbits)
{
  switch (nbits) {
  default:
  case 1:	return (v[i>>3] >>  (i&7)    ) &  1;
  case 2:	return (v[i>>2] >> ((i&3)<<1)) &  3;
  case 4:	return (v[i>>1] >> ((i&1)<<2)) & 15;
  case 8:	return (v[i]);
  case 16:	i <<= 1; return (v[i]<<8)  | (v[i+1]);
  case 32:	i <<= 2; return (v[i]<<24) | (v[i+1]<<16) | (v[i+2]<<8) | (v[i+3]);
  }
}

//--------------------------------------------------------------
static inline void absv_vset(uchar *v, uint i, uint nbits, uint val)
{
  uint b;
  //fprintf(stderr, "DEBUG: vset(nbits=%u, i=%u, val=%u)\n", nbits,i,val);
  switch (nbits) {
  default:
  case 1:	b=i&7;      i>>=3; v[i] = (v[i]&~( 1<<b)) | ((val& 1)<<b); break;
  case 2:	b=(i&3)<<1; i>>=2; v[i] = (v[i]&~( 3<<b)) | ((val& 3)<<b); break;
  case 4:	b=(i&1)<<2; i>>=1; v[i] = (v[i]&~(15<<b)) | ((val&15)<<b); break;
  case 8:	v[i] = (val & 255); break;
  case 16:	v += (i<<1); *v++=(val>> 8)&0xff; *v=(val&0xff); break;
  case 32:	v += (i<<2); *v++=(val>>24)&0xff; *v++=(val>>16)&0xff; *v++=(val>>8)&0xff; *v=val&0xff; break;
  }
}

//--------------------------------------------------------------
static uint absv_bsearch(const uchar *v, uint key, uint ilo, uint ihi, uint nbits)
{
  while (ilo < ihi) {
    uint imid = (ilo+ihi) >> 1;
    if (absv_vget(v, imid, nbits) < key)
      ilo = imid + 1;
    else
      ihi = imid;
  }
  if ((ilo == ihi) && (absv_vget(v,ilo,nbits) == key))
    return ilo;
  else
    return KEY_NOT_FOUND;
}

//--------------------------------------------------------------
static uint absv_bsearch_lb(const uchar *v, uint key, uint ilo, uint ihi, uint nbits)
{
 uint imid;
 while (ihi-ilo > 1) {
   imid = (ihi+ilo) >> 1;
   if (absv_vget(v, imid, nbits) < key) {
     ilo = imid;
   } else {
     ihi = imid;
   }
 }
 if (absv_vget(v,ilo,nbits)==key) return ilo;
 if (absv_vget(v,ihi,nbits)<=key) return ihi;
 return ilo==0 ? KEY_NOT_FOUND : ilo;
}

//--------------------------------------------------------------
static uint absv_bsearch_ub(const uchar *v, uint key, uint ilo, uint ihi, uint nbits)
{
 uint imid;
 while (ihi-ilo > 1) {
   imid = (ihi+ilo) >> 1;
   if (absv_vget(v, imid, nbits) > key) {
     ihi = imid;
   } else {
     ilo = imid;
   }
 }
 if (absv_vget(v,ihi,nbits)==key) return ihi;
 if (absv_vget(v,ilo,nbits)>=key) return ilo;
 return ihi;
}

/*==============================================================================
 * XS Guts
 */

MODULE = Algorithm::BinarySearch::Vec    PACKAGE = Algorithm::BinarySearch::Vec::XS

PROTOTYPES: ENABLE

##=====================================================================
## DEBUG
##=====================================================================

##--------------------------------------------------------------
uint
vget(SV *vec, uint i, uint nbits)
PREINIT:
  uchar *vp;
CODE:
 vp = (uchar *)SvPV_nolen(vec);
 RETVAL = absv_vget(vp, i, nbits);
OUTPUT:
  RETVAL

##--------------------------------------------------------------
void
vset(SV *vec, uint i, uint nbits, uint val)
PREINIT:
  uchar *vp;
CODE:
 vp = (uchar *)SvPV_nolen(vec);
 absv_vset(vp, i, nbits, val);


##=====================================================================
## BINARY SEARCH, element-wise

##--------------------------------------------------------------
uint
vbsearch(SV *vec, uint key, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 RETVAL = absv_bsearch(v,key,ilo,ihi,nbits);
OUTPUT:
 RETVAL

##--------------------------------------------------------------
uint
vbsearch_lb(SV *vec, uint key, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 RETVAL = absv_bsearch_lb(v,key,ilo,ihi,nbits);
OUTPUT:
 RETVAL

##--------------------------------------------------------------
uint
vbsearch_ub(SV *vec, uint key, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 RETVAL = absv_bsearch_ub(v,key,ilo,ihi,nbits);
OUTPUT:
 RETVAL


##=====================================================================
## BINARY SEARCH, array-wise

##--------------------------------------------------------------
AV*
vabsearch(SV *haystack, AV *needle, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
  I32 i,n;
CODE:
 v = SvPV(haystack,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n = av_len(needle);
 RETVAL = newAV();
 av_extend(RETVAL, n);
 for (i=0; i<=n; ++i) {
   SV   **key   = av_fetch(needle, i, 0);
   uint   found = absv_bsearch(v,SvUV(*key),ilo,ihi,nbits);
   av_store(RETVAL, i, newSVuv(found));
 }
OUTPUT:
 RETVAL

##--------------------------------------------------------------
AV*
vabsearch_lb(SV *haystack, AV *needle, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
  I32 i,n;
CODE:
 v = SvPV(haystack,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n = av_len(needle);
 RETVAL = newAV();
 av_extend(RETVAL, n);
 for (i=0; i<=n; ++i) {
   SV   **key   = av_fetch(needle, i, 0);
   uint   found = absv_bsearch_lb(v,SvUV(*key),ilo,ihi,nbits);
   av_store(RETVAL, i, newSVuv(found));
 }
OUTPUT:
 RETVAL

##--------------------------------------------------------------
AV*
vabsearch_ub(SV *haystack, AV *needle, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
  I32 i,n;
CODE:
 v = SvPV(haystack,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n = av_len(needle);
 RETVAL = newAV();
 av_extend(RETVAL, n);
 for (i=0; i<=n; ++i) {
   SV   **key   = av_fetch(needle, i, 0);
   uint   found = absv_bsearch_ub(v,SvUV(*key),ilo,ihi,nbits);
   av_store(RETVAL, i, newSVuv(found));
 }
OUTPUT:
 RETVAL
