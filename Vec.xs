/*-*- Mode: C -*- */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
/*#include "ppport.h"*/

#ifndef uchar
typedef unsigned char uchar;
#endif

const U32 KEY_NOT_FOUND = 0xffffffff;

/*==============================================================================
 * Utils
 */

//--------------------------------------------------------------
static inline int absv_cmp(U32 a, U32 b)
{
  if      (a<b) return -1;
  else if (a>b) return  1;
  return 0;
}

//--------------------------------------------------------------
static inline U32 absv_vget(const uchar *v, U32 i, U32 nbits)
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
static inline void absv_vset(uchar *v, U32 i, U32 nbits, U32 val)
{
  U32 b;
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
static U32 absv_bsearch(const uchar *v, U32 key, U32 ilo, U32 ihi, U32 nbits)
{
  while (ilo < ihi) {
    U32 imid = (ilo+ihi) >> 1;
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
static U32 absv_bsearch_lb(const uchar *v, U32 key, U32 ilo, U32 ihi, U32 nbits)
{
 U32 imid, imin=ilo, imax=ihi;
 while (ihi-ilo > 1) {
   imid = (ihi+ilo) >> 1;
   if (absv_vget(v, imid, nbits) < key) {
     ilo = imid;
   } else {
     ihi = imid;
   }
 }
 if (              absv_vget(v,ilo,nbits)==key) return ilo;
 if (ihi < imax && absv_vget(v,ihi,nbits)==key) return ihi;
 if (ilo > imin || absv_vget(v,ilo,nbits) <key) return ilo;
 return KEY_NOT_FOUND;
}

//--------------------------------------------------------------
static U32 absv_bsearch_ub(const uchar *v, U32 key, U32 ilo, U32 ihi, U32 nbits)
{
 U32 imid, imax=ihi;
 while (ihi-ilo > 1) {
   imid = (ihi+ilo) >> 1;
   if (absv_vget(v, imid, nbits) > key) {
     ihi = imid;
   } else {
     ilo = imid;
   }
 }
 if (ihi<imax && absv_vget(v,ihi,nbits)==key) return ihi;
 if (            absv_vget(v,ilo,nbits)>=key) return ilo;
 return ihi>=imax ? KEY_NOT_FOUND : ihi;
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
U32
vget(SV *vec, U32 i, U32 nbits)
PREINIT:
  uchar *vp;
CODE:
 vp = (uchar *)SvPV_nolen(vec);
 RETVAL = absv_vget(vp, i, nbits);
OUTPUT:
  RETVAL

##--------------------------------------------------------------
void
vset(SV *vec, U32 i, U32 nbits, U32 val)
PREINIT:
  uchar *vp;
CODE:
 vp = (uchar *)SvPV_nolen(vec);
 absv_vset(vp, i, nbits, val);


##=====================================================================
## BINARY SEARCH, element-wise

##--------------------------------------------------------------
U32
vbsearch(SV *vec, U32 key, U32 nbits, ...)
PREINIT:
  const uchar *v;
  STRLEN vlen;
  U32 ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 RETVAL = absv_bsearch(v,key,ilo,ihi,nbits);
OUTPUT:
 RETVAL

##--------------------------------------------------------------
U32
vbsearch_lb(SV *vec, U32 key, U32 nbits, ...)
PREINIT:
  const uchar *v;
  STRLEN vlen;
  U32 ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 RETVAL = absv_bsearch_lb(v,key,ilo,ihi,nbits);
OUTPUT:
 RETVAL

##--------------------------------------------------------------
U32
vbsearch_ub(SV *vec, U32 key, U32 nbits, ...)
PREINIT:
  const uchar *v;
  STRLEN vlen;
  U32 ilo, ihi;
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
vabsearch(SV *vec, AV *keys, U32 nbits, ...)
PREINIT:
  const uchar *v;
  STRLEN vlen;
  U32 ilo, ihi;
  I32 i,n;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n = av_len(keys);
 RETVAL = newAV();
 av_extend(RETVAL, n);
 for (i=0; i<=n; ++i) {
   SV   **key  = av_fetch(keys, i, 0);
   U32   found = absv_bsearch(v,SvUV(*key),ilo,ihi,nbits);
   av_store(RETVAL, i, newSVuv(found));
 }
OUTPUT:
 RETVAL

##--------------------------------------------------------------
AV*
vabsearch_lb(SV *vec, AV *keys, U32 nbits, ...)
PREINIT:
  const uchar *v;
  STRLEN vlen;
  U32 ilo, ihi;
  I32 i,n;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n = av_len(keys);
 RETVAL = newAV();
 av_extend(RETVAL, n);
 for (i=0; i<=n; ++i) {
   SV   **key  = av_fetch(keys, i, 0);
   U32   found = absv_bsearch_lb(v,SvUV(*key),ilo,ihi,nbits);
   av_store(RETVAL, i, newSVuv(found));
 }
OUTPUT:
 RETVAL

##--------------------------------------------------------------
AV*
vabsearch_ub(SV *vec, AV *keys, U32 nbits, ...)
PREINIT:
  const uchar *v;
  STRLEN vlen;
  U32 ilo, ihi;
  I32 i,n;
CODE:
 v = SvPV(vec,vlen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n = av_len(keys);
 RETVAL = newAV();
 av_extend(RETVAL, n);
 for (i=0; i<=n; ++i) {
   SV   **key  = av_fetch(keys, i, 0);
   U32   found = absv_bsearch_ub(v,SvUV(*key),ilo,ihi,nbits);
   av_store(RETVAL, i, newSVuv(found));
 }
OUTPUT:
 RETVAL

##=====================================================================
## BINARY SEARCH, vec-wise

##--------------------------------------------------------------
SV*
vvbsearch(SV *vec, SV *vkeys, U32 nbits, ...)
PREINIT:
  const uchar *v, *k;
  uchar *rv;
  STRLEN vlen, klen;
  U32 i,n, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 k = SvPV(vkeys,klen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n   = klen*8/nbits;
 RETVAL = newSVpv("",0);
 SvGROW(RETVAL, n*4);		/*-- always use 32-bit keys --*/
 SvCUR_set(RETVAL, n*4);
 rv = SvPV_nolen(RETVAL);
 for (i=0; i<n; ++i) {
   U32 key   = absv_vget(k,i,nbits);
   U32 found = absv_bsearch(v,key,ilo,ihi,nbits);
   absv_vset(rv,i,32,found);
 }
OUTPUT:
 RETVAL

##--------------------------------------------------------------
SV*
vvbsearch_lb(SV *vec, SV *vkeys, U32 nbits, ...)
PREINIT:
  const uchar *v, *k;
  uchar *rv;
  STRLEN vlen, klen;
  U32 i,n, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 k = SvPV(vkeys,klen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n   = klen*8/nbits;
 RETVAL = newSVpv("",0);
 SvGROW(RETVAL, n*4);		/*-- always use 32-bit keys --*/
 SvCUR_set(RETVAL, n*4);
 rv = SvPV_nolen(RETVAL);
 for (i=0; i<n; ++i) {
   U32 key   = absv_vget(k,i,nbits);
   U32 found = absv_bsearch_lb(v,key,ilo,ihi,nbits);
   absv_vset(rv,i,32,found);
 }
OUTPUT:
 RETVAL

##--------------------------------------------------------------
SV*
vvbsearch_ub(SV *vec, SV *vkeys, U32 nbits, ...)
PREINIT:
  const uchar *v, *k;
  uchar *rv;
  STRLEN vlen, klen;
  U32 i,n, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 k = SvPV(vkeys,klen);
 ilo = items > 3 ? SvUV(ST(3)) : 0;
 ihi = items > 4 ? SvUV(ST(4)) : (vlen*8/nbits);
 n   = klen*8/nbits;
 RETVAL = newSVpv("",0);
 SvGROW(RETVAL, n*4);		/*-- always use 32-bit keys --*/
 SvCUR_set(RETVAL, n*4);
 rv = SvPV_nolen(RETVAL);
 for (i=0; i<n; ++i) {
   U32 key   = absv_vget(k,i,nbits);
   U32 found = absv_bsearch_ub(v,key,ilo,ihi,nbits);
   absv_vset(rv,i,32,found);
 }
OUTPUT:
 RETVAL
