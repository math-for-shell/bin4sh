#!/bin/dash
# written in pure posix-compliant shell with no external calls -works under bash or dash(~3 times faster)
# Copyright Gilbert Ashley 29 December 2020
# -compare, add, subtract, multiply or divide binary numbers, with or without fractions
# -convert numbers from decimal to binary, or binary to decimal
# -performs binary calculation on decimal inputs and outputs the result in decimal (using d2d_ops function)
# version=2.6
# 
# new dec_add_E does E-notation decimal addition

# see the end of this file for help text
default_scale=5

# For operations of any complexity, like controlling loops, we need to compare values.
# In the shell numeric comparisons using 'test' or '[ ? -gt ? ]' are limited to 19 digits,
# just as the shells' arithmetic operations are limited to 19 digits input or output.
# This function will compare binary numbers which are thousands of digits long.
# bin_compare_tri - three-way comparison of two binary numbers -outputs '>' '<' or '='
bin_compare_tri(){ bc3w_1=$1 bc3w_2=$2
    case $bc3w_1 in '-'*) bctsign1='-' bc3w_1=${bc3w_1#*-};; 
        '+'*) bctsign1='+' bc3w_1=${bc3w_1#*+};; *) bctsign1='+';; esac
    case $bc3w_2 in '-'*) bctsign2='-' bc3w_2=${bc3w_2#*-};; 
        '+'*) bctsign2='+' bc3w_2=${bc3w_2#*+};; *) bctsign2='+';; esac
    case $bc3w_1 in *.*) bc3w_1_i=${bc3w_1%.*} bc3w_1_f=${bc3w_1#*.} ;; *) bc3w_1_i=$bc3w_1 bc3w_1_f= ;; esac
    case $bc3w_2 in *.*) bc3w_2_i=${bc3w_2%.*} bc3w_2_f=${bc3w_2#*.} ;; *) bc3w_2_i=$bc3w_2 bc3w_2_f= ;; esac
    # remove all extra zeros in order to check if either number equals zero
    while : ; do case $bc3w_1_f in *?0) bc3w_1_f=${bc3w_1_f%?*} ;; *) break ;; esac ; done
    while : ; do case $bc3w_2_f in *?0) bc3w_2_f=${bc3w_2_f%?*} ;; *) break ;; esac ; done
    while : ; do case $bc3w_1_i in 0?*) bc3w_1_i=${bc3w_1_i#*?} ;; *) break ;; esac ; done
    while : ; do case $bc3w_2_i in 0?*) bc3w_2_i=${bc3w_2_i#*?} ;; *) break ;; esac ; done
    # recombine integers and fractions without the radix
    bc3w_1=$bc3w_1_i$bc3w_1_f ; bc3w_2=$bc3w_2_i$bc3w_2_f
    # handle cases where one of the numbers is zero
    case $bc3w_1 in 
        0|00) case $bc3w_2 in 0|00) echo '=' ; return ;; 
                    *) [ "$bctsign2" = '-' ] && { echo '>' ; return ;} || { echo '<' ; return ;} ;; esac ;; esac
    case $bc3w_2 in 
        0|00) case $bc3w_1 in 0|00) echo '=' ; return ;; 
                    *) [ "$bctsign1" = '-' ] && { echo '<' ; return ;} || { echo '>' ; return ;} ;; esac ;; esac
    # otherwise, post-pad the fractions until equal length
    while [ ${#bc3w_1_f} -lt ${#bc3w_2_f} ] ; do  bc3w_1_f=$bc3w_1_f'0' ; done
    while [ ${#bc3w_2_f} -lt ${#bc3w_1_f} ] ; do  bc3w_2_f=$bc3w_2_f'0' ; done
    # front-pad the integers until equal length
    while [ ${#bc3w_1_i} -lt ${#bc3w_2_i} ] ; do  bc3w_1_i='0'$bc3w_1_i ; done
    while [ ${#bc3w_2_i} -lt ${#bc3w_1_i} ] ; do  bc3w_2_i='0'$bc3w_2_i ; done
    # re-combine padded integers and padded fractions without the radix
    bc3w_1=$bc3w_1_i$bc3w_1_f ; bc3w_2=$bc3w_2_i$bc3w_2_f
    # early result if signs of numbers are different
    case $bctsign1$bctsign2 in '+-') echo '>' ; return ;; '-+') echo '<' ; return ;; esac
    # if both numbers are negative, swapping their places gives correct output
    case $bctsign1$bctsign2 in '--') bs_swap=$bc3w_2 bc3w_2=$bc3w_1 bc3w_1=$bs_swap ;; esac
    # compare digit-by-digit from left to right
    while [ -n "$bc3w_1" ] ; do # compare the MSB's and return if different
        case "${bc3w_1%${bc3w_1#*?}*}""${bc3w_2%${bc3w_2#*?}*}" in
            10) echo '>' ; return ;; 01) echo '<' ; return ;;
        esac
        bc3w_1=${bc3w_1#*?}  bc3w_2=${bc3w_2#*?}    # or go to next two digits
    done # if we arrive here the two numbers are equal
    echo '='
}
# bin_compare_tri -example usage: bin_compare_tri 422 123  (returns '>')

# bin_test - familiar one-way comparisons with true/false output, as used by the posix shell
# with 'test' or '[]'. bin_compare_tri provides the relationship determination 
bin_test() { N1_bin_test=$1 op_bin_test=$2 N2_bin_test=$3
    ret=$( bin_compare_tri $N1_bin_test $N2_bin_test )
    case $op_bin_test in
        '-lt') [ "$ret" = '<' ] && return 0 || return 1 ;;
        '-le')  case $ret in '<'|'=') return 0 ;; *) return 1 ;; esac ;;
        '-eq') [ "$ret" = '=' ] && return 0 || return 1 ;;
        '-ge')  case $ret in '>'|'=') return 0 ;; *) return 1 ;; esac ;;
        '-gt') [ "$ret" = '>' ] && return 0 || return 1 ;;
        '-ne')  case $ret in '=') return 1 ;; *) return 0 ;; esac ;;
    esac
}
# bin_test -example usage: bin_test 1111 -gt 0100 && echo "#1 is greater than #2"

# bin_add - sum two or more binary numbers (absolute values)
# addition by digit/bit comparison -using no math operators, except numeric tests
# Use bin_add_sub for any operations using mixed signs or mixed operators.
bin_add(){ out_sum=$1 ; shift
    while [ $1 ] ; do n1_bsm=$out_sum n2_bsm=$1 carry_bsm=0
        case $n1_bsm in *.*) n1_bsm_i=${n1_bsm%.*} n1_bsm_f=${n1_bsm#*.} ;; *) n1_bsm_i=$n1_bsm n1_bsm_f= ;; esac
        case $n2_bsm in *.*) n2_bsm_i=${n2_bsm%.*} n2_bsm_f=${n2_bsm#*.} ;; *) n2_bsm_i=$n2_bsm n2_bsm_f= ;; esac
        while [ ${#n1_bsm_f} -lt ${#n2_bsm_f} ] ; do n1_bsm_f=$n1_bsm_f'0' ;  done  # pad fractions
        while [ ${#n2_bsm_f} -lt ${#n1_bsm_f} ] ; do n2_bsm_f=$n2_bsm_f'0' ;  done
        bsm_frac_len=${#n1_bsm_f} ; n1_bsm=$n1_bsm_i$n1_bsm_f ; n2_bsm=$n2_bsm_i$n2_bsm_f   # set frac_len, remove radix
        while [ ${#n1_bsm} -lt ${#n2_bsm} ] ; do n1_bsm='0'$n1_bsm ;  done  # front-pad integers
        while [ ${#n2_bsm} -lt ${#n1_bsm} ] ; do n2_bsm='0'$n2_bsm ;  done
        while [ -n "$n2_bsm" ] ; do # work from right to left (<-LSB)
            mask1_bsm=${n1_bsm%?*} mask2_bsm=${n2_bsm%?*}
            # 1st bit of pattern is the carry bit, 2nd is the MSB of 1st number, 3rd the MSB of 2nd number
            pat="${carry_bsm}""${n1_bsm#*${mask1_bsm}}""${n2_bsm#*${mask2_bsm}}"
            case $pat in
                    011|110|101) out_bsm='0'$out_bsm carry_bsm=1 ;; # these 3 states set the carry bit
                    111) out_bsm='1'$out_bsm carry_bsm=1 ;; # this state continues the carry
                    100) out_bsm='1'$out_bsm carry_bsm=0 ;; # this state cancels the carry bit
                    010|001) out_bsm='1'$out_bsm carry_bsm=0 ;; # in these 3 states the
                    000) out_bsm='0'$out_bsm carry_bsm=0 ;; # carry bit is off and stays off
            esac
            n1_bsm=$mask1_bsm n2_bsm=$mask2_bsm # move to the next LSB's
        done
        [ "$carry_bsm" = 1 ] && out_bsm='1'$out_bsm
        out_sum=$out_bsm out_bsm=
        if [ $bsm_frac_len -gt 0 ] ; then   # separate integer and fractional parts, if present
            while [ ${#out_sum} -gt $bsm_frac_len ] ; do
                mask1_bsm=${out_sum#*?} ; out_bsm_i=$out_bsm_i${out_sum%$mask1_bsm*} ; out_sum=$mask1_bsm
            done
            out_sum=$out_bsm_i'.'$out_sum
        fi
        shift   # go to the next input
    done
    echo $out_sum
}
# bin_add -example usage: bin_add 1100.01 1010.1  -or-  1100 1010.1 1000 ...

# bin_sub - subtraction by addition (add the minuend to the two's complement of the subtrahend)
# or if 2nd number is bigger, switch their postions and negate the result. This function will not
# correctly subtract numbers once the current output value becomes negtive. Use bin_add_sub instead.
# like for bin_add, input can be a series of numbers
bin_sub(){ n1_bs=$1 ; shift
    while [ $1 ] ; do n2_bs=$1 bs_neg=
        case $n1_bs in *.*) n1_bs_i=${n1_bs%.*} n1_bs_f=${n1_bs#*.} ;; *) n1_bs_i=$n1_bs n1_bs_f= ;; esac
        case $n2_bs in *.*) n2_bs_i=${n2_bs%.*} n2_bs_f=${n2_bs#*.} ;; *) n2_bs_i=$n2_bs n2_bs_f= ;; esac
        while [ ${#n1_bs_f} -lt ${#n2_bs_f} ] ; do n1_bs_f=$n1_bs_f'0' ;  done # equalize fraction lengths
        while [ ${#n2_bs_f} -lt ${#n1_bs_f} ] ; do n2_bs_f=$n2_bs_f'0' ;  done
        while [ ${#n1_bs_i} -lt ${#n2_bs_i} ] ; do n1_bs_i='0'$n1_bs_i ;  done # equalize integer lengths
        while [ ${#n2_bs_i} -lt ${#n1_bs_i} ] ; do n2_bs_i='0'$n2_bs_i ;  done
        # recombine after padding, since bin_add handles fractions itself
        case $n1_bs_f in '') n1_bs=$n1_bs_i ;; *) n1_bs=$n1_bs_i'.'$n1_bs_f ;; esac
        case $n2_bs_f in '') n2_bs=$n2_bs_i ;; *) n2_bs=$n2_bs_i'.'$n2_bs_f ;; esac
        # if 2nd number is bigger, switch positions and set output sign to negative
        bin_test $n2_bs -gt $n1_bs && bs_swap=$n2_bs n2_bs=$n1_bs n1_bs=$bs_swap bs_neg='-'
        # add the two's complement of the 2nd number to the 1st number
        out_bs=$( bin_add $n1_bs $(twos_complement $n2_bs) )
        # result is always one digit too long, so strip off the 'extra' first digit
        out_bs=${out_bs#*?} ;
        # catenate the current output and sign, reset vars and go to next input, if any
        n1_bs=$bs_neg${out_bs} bs_neg= out_bs= comp=
        shift
    done    
    echo $n1_bs
}
# bin_sub -example usage: bin_sub 1110 0010  -or-  bin_sub 1110 10 11 ...

# twos_complement -instead of deriving the one's complement and adding 1 
# to get the two's complement, simply skip over and copy right-most zeros, until we reach 
# the first 1, copy that to the output, then flip remaining bits and copy until done
twos_complement(){ tc2=$1
    while [ -n "$tc2" ] ; do
        case $tc2 in *'0') tc2_out='0'$tc2_out tc2=${tc2%0*} ;; 
            *'.') tc2_out='.'$tc2_out tc2=${tc2%.*} ;; *) break ;; esac
    done
    tc2_out='1'$tc2_out tc2=${tc2%1*}
    while [ -n "$tc2" ] ; do
        case $tc2 in *'0') tc2_out='1'$tc2_out tc2=${tc2%0*} ;; 
            *'.') tc2_out='.'$tc2_out tc2=${tc2%.*} ;; 
            *) tc2_out='0'$tc2_out tc2=${tc2%1*} ;; esac
    done
    echo $tc2_out
}

# bin_add_sub - add and/or subtract a series of binary numbers separated by + and/or - operators 
# between the operands which can be signed, un-signed or have mixed signs
bin_add_sub(){ bas_out=$1 ; shift
    while [ $1 ] ; do bas_oprtr=$1 bas_oprnd=$2 bas_out_f= bas_oprnd_f=
        case $bas_out in '-'*) bas_sign1='-' bas_out=${bas_out#*-};; *) bas_sign1='+' bas_out=${bas_out#*+};; esac
        case $bas_oprnd in '-'*) bas_sign2='-' bas_oprnd=${bas_oprnd#*-};; *) bas_sign2='+' bas_oprnd=${bas_oprnd#*+};; esac
        case $bas_out in *.*) bas_out_i=${bas_out%.*} bas_out_f=${bas_out#*.};; *) bas_out_i=$bas_out;; esac
        case $bas_oprnd in *.*)bas_oprnd_i=${bas_oprnd%.*} bas_oprnd_f=${bas_oprnd#*.};; *) bas_oprnd_i=$bas_oprnd;; esac
        while [ ${#bas_out_f} -lt ${#bas_oprnd_f} ] ; do bas_out_f=$bas_out_f'0' ; done
        while [ ${#bas_oprnd_f} -lt ${#bas_out_f} ] ; do bas_oprnd_f=$bas_oprnd_f'0' ; done
        bas_out=$bas_out_i$bas_out_f  bas_oprnd=$bas_oprnd_i$bas_oprnd_f # recombine numbers without radix
        
        if bin_test $bas_out -eq 0 ; then
            case $bas_oprtr$bas_sign2 in '--'|'++') bas_out_sign='+' ;; '-+'|'+-') bas_out_sign='-';; esac
            [ ${#bas_oprnd_f} -gt 0 ] && bas_out=$bas_oprnd_i'.'$bas_oprnd_f || bas_out=$bas_oprnd_i
        elif bin_test $bas_oprnd -eq 0 ; then
            [ ${#bas_out_f} -gt 0 ] && bas_out=$bas_out_i'.'$bas_out_f
            bas_out_sign=$bas_sign1
        else
            # simplify the operator and sign of the second number
            case ${bas_oprtr}${bas_sign2} in '++'|'--') bas_sign2='+' ;; '+-'|'-+') bas_sign2='-' ;; esac
            # if the absolute value of the 2nd number is greater than the 1st, swap their places
            case $(bin_compare_tri $bas_out $bas_oprnd) in  '<') A_int=$bas_out_i A_sign=$bas_sign1 A_frac=$bas_out_f 
                bas_oprnd_i=$bas_out_i bas_sign2=$bas_sign1 bas_oprnd_f=$bas_out_f 
                bas_out_i=$A_int bas_sign1=$A_sign bas_out_f=$A_frac ;;
            esac
            # the sign of the number with the greater absolute value determines the sign of the result
            bas_out_sign=$bas_sign1
            # determine the real operation to perform
            case ${bas_sign1}${bas_sign2} in '+-'|'-+') bas_oprtr='-' ;; *) bas_oprtr='+' ;; esac
            # reinsert radices if present
            case $bas_out_f in '') : ;; *) bas_out=$bas_out_i'.'$bas_out_f;; esac
            case $bas_oprnd_f in '') : ;;  *) bas_oprnd=$bas_oprnd_i'.'$bas_oprnd_f ;;  esac
            case $bas_oprtr in 
                '+') bas_out=$(bin_add $bas_out $bas_oprnd) ;;
                '-') bas_out=$(bin_sub $bas_out $bas_oprnd) ;;
            esac
        fi
        bin_test $bas_out -eq 0 &&  bas_out_sign=
        bas_out=${bas_out_sign#*+}$bas_out
        shift 2
    done
    echo $bas_out
}
# bin_add_sub - example usage: bin_add_sub 100.1 + 1110.11  -or- bin_add_sub 1110 + 100 - 10 

# bin_mul - binary mutliplication by addition
# multiply two or more binary numbers, with or without fractions
bin_mul(){ case $1 in 'scale='*|'-s'*) bm_scale=${1#=*} bm_scale=${1#-s*}; shift ;;  esac
    bm_num1=$1 ; shift
    while [ $1 ] ; do mltplr=$1 
        case $bm_num1 in '-'*) n1_sgn='-' bm_num1=${bm_num1#?*} ;; 
            '+'*) n1_sgn='+' bm_num1=${bm_num1#?*} ;; *) n1_sgn='+' ;; esac
        case $mltplr in '-'*) n2_sgn='-' mltplr=${mltplr#?*} ;; 
            '+'*) n2_sgn='+' mltplr=${mltplr#?*} ;; *) n2_sgn='+' ;; esac
        #bm_out=0 col=
        [ ${#bm_num1} -gt ${#mltplr} ] && swap=$bm_num1 bm_num1=$mltplr mltplr=$swap
        case $bm_num1 in 
            .*)bm_num1_i=0 bm_num1_f=${bm_num1#*.};;
            *.*) bm_num1_i=${bm_num1%.*} bm_num1_f=${bm_num1#*.};;
            *) bm_num1_i=$bm_num1 bm_num1_f= ;; 
        esac
        case $mltplr in 
            .*) mltplr_i=0 mltplr_f=${mltplr#*.};;
            *.*) mltplr_i=${mltplr%.*} mltplr_f=${mltplr#*.};; 
            *) mltplr_i=$mltplr mltplr_f= ;;  
        esac
        bm_frac_size=$(( ${#bm_num1_f} + ${#mltplr_f} ))
        bm_num1=$bm_num1_i$bm_num1_f mltplr=$mltplr_i$mltplr_f
        bm_out=0 col=
        while [ -n "$bm_num1" ] ; do
            num2=$mltplr mask1=${bm_num1%*?} A=${bm_num1#$mask1*}
            case $A in
                0) bm_out='0'$bm_out ;;
                *)
                    while [ -n "$num2" ] ; do
                        mask2=${num2%*?} B=${num2#$mask2*}
                        case $A$B in 
                            11) this='1'$this ;; 
                            *) this='0'$this ;; 
                        esac
                        num2=$mask2
                    done
                    bm_out=$( bin_add $bm_out $this$col )
                ;;
            esac
            this= col=$col'0' bm_num1=$mask1
        done
         # determine the sign of the result
        case ${n1_sgn}${n2_sgn} in '++'|'--') bm_sgn='' ;; '+-'|'-+') bm_sgn='-' ;; esac
        # separate the integer and fractional parts
        if [ $bm_frac_size -gt 0 ] ; then
            while [ ${#bm_out} -gt $bm_frac_size ] ; do
                bm_mask=${bm_out#?*} dig=${bm_out%*$bm_mask} bm_out_i=$bm_out_i$dig bm_out=$bm_mask
            done
            # if scale was given
            if [ -n "$bm_scale" ] ; then # and is smaller than frac_size, trim result
                [ $bm_frac_size -gt $bm_scale ] && bm_out=$(printf "%.*s" $bm_scale $bm_out)
            fi
            bm_frac=$bm_out 
            #while : ; do  case $bm_frac in *?0) bm_frac=${bm_frac%*?};; *) break;; esac ;  done
            while : ; do  case $bm_out_i in '0'?*) bm_out_i=${bm_out_i#?*};; *) break;; esac ;  done
            bm_num1=$bm_out_i.$bm_frac
        else
            bm_num1=$bm_out
        fi
        # remove leading zeros and apply the sign
        #while : ; do  case $bm_num1 in 0?*) bm_num1=${bm_num1#?*};; *) break;; esac ;  done
        # if answer is zero use no sign
        bin_test $bm_num1 -eq 0 && bm_sgn=
        bm_num1=$bm_sgn$bm_num1
        shift
    done
    echo $bm_num1
}
# bin_mul -example usage: bin_mul 1100 10  -or-  1100 10 -100 ...

# bin_div - binary division by subtraction
# uses default scale if scale not given (as first option: scale=? or -s?)
bin_div(){  
    case $1 in 
        'scale='*|'-s'*) bd_scale=${1#*=} bd_scale=${bd_scale#*'-s'} ; shift ;; 
        *) bd_scale=$default_scale ;;
    esac
    dvdnd=$1 ; shift
    while [ $1 ] ; do dvsr=$1
        case $dvdnd in '-'*) n1sgn='-' dvdnd=${dvdnd#*-} ;; *) n1sgn='+' ;; esac
        case $dvsr in '-'*) n2sgn='-' dvsr=${dvsr#*-} ;; *) n2sgn='+' ;; esac
        case $dvdnd in *.*) dvdnd_i=${dvdnd%.*} dvdnd_f=${dvdnd#*.} ;; *) dvdnd_i=$dvdnd ;; esac
        case $dvsr in *.*) dvsr_i=${dvsr%.*} dvsr_f=${dvsr#*.} ;; *) dvsr_i=$dvsr ;; esac
        
        while [ ${#dvdnd_f} -lt ${#dvsr_f} ] ; do dvdnd_f=$dvdnd_f'0' ; done
        while [ ${#dvsr_f} -lt ${#dvdnd_f} ] ; do dvsr_f=$dvsr_f'0' ; done
        dvdnd=$dvdnd_i$dvdnd_f dvsr=$dvsr_i$dvsr_f
        while : ; do case $dvdnd in 0*) dvdnd=${dvdnd#*?};; *) break ;; esac ; done
        while : ; do case $dvsr in 0*) dvsr=${dvsr#*?};; *) break ;; esac ; done
        
        # get the integer part
        if [ ${#dvdnd} -lt ${#dvsr} ] || bin_test $dvdnd -lt $dvsr ; then
            bd_Q_int=0
        else
            bin_cnt=0 limit=$(( ${#dvdnd} - 1 )) 
            if [ $limit -gt ${#dvsr} ] ; then
                pwr=$(printf "%0""$(( $limit - ${#dvsr} ))""d")
                dvdnd=$(bin_sub $dvdnd $dvsr$pwr) ; bin_cnt='1'$pwr
            fi
            while bin_test $dvsr -le $dvdnd ; do
                dvdnd=$(bin_sub $dvdnd $dvsr) ; bin_cnt=$(bin_add $bin_cnt 1)
            done
            bd_Q_int=$bin_cnt
        fi
        # do the fractional part, if present
        if bin_test $dvdnd -ne 0 ; then
            bd_Q_frac= mod=$dvdnd
            while [ ${#bd_Q_frac} -lt ${bd_scale} ] ; do
                bin_test $mod -eq 0 && break || mod=$mod'0'
                if bin_test $mod -lt $dvsr ; then
                    bd_Q_frac=$bd_Q_frac'0'
                else  
                    mod=$( bin_sub $mod $dvsr )
                    bd_Q_frac=$bd_Q_frac'1'
                fi
            done
        fi
        # determine the sign of the result
        case "${n1sgn}${n2sgn}" in '++'|'--') div_sgn='' ;; '+-'|'-+') div_sgn='-' ;; esac
        [ -n "$bd_Q_frac" ] && dvdnd=$div_sgn$bd_Q_int.$bd_Q_frac || dvdnd=$div_sgn$bd_Q_int
        shift
    done
    echo $dvdnd
}
# bin_div -example usage: bin_div scale=6 1100 10  -or-  bin_div 1110 100 10


# bin_to_dec - convert binary numbers to decimal, including fractions
# for integers uses decimal addition via shell addition or dec_add
# for fractions uses shell multiplication or dec_pow_5
bin_to_dec(){ 
    case $1 in '-r'|'raw') raw_output=1 ; shift ;; esac
    case $1 in '-s'*|'scale='*) btd_scale=${1#*'-s'}  btd_scale=${btd_scale#*'scale='} ; shift ;; esac
    case $1 in *.*) x_btd=${1%.*} x_btd_frac=${1#*.} out_btd_frac=0 ;; *) x_btd=$1 ;; esac
    case $x_btd in '-'*) btdneg='-' x_btd=${x_btd#*?}  ;; esac ; out_btd=0 x_btd_cnt=0
    #
    while [ -n "$x_btd" ] ; do
        case $x_btd in 0*)out_btd=$(($out_btd + $out_btd)) ;; 1*)out_btd=$(($out_btd + $out_btd + 1)) ;; esac
        x_btd=${x_btd#*?} x_btd_cnt=$(($x_btd_cnt + 1)) ; [ $x_btd_cnt -eq 63 ] && break
    done
    while [ -n "$x_btd" ] ; do
        case $x_btd in 0*)out_btd=$(dec_add $out_btd $out_btd) ;; 1*)out_btd=$(dec_add $out_btd $out_btd 1) ;; esac
        x_btd=${x_btd#*?}
    done
    if [ -n "$x_btd_frac" ] ; then btd_col='' col_cnt=1 frac_size=${#x_btd_frac}
        if [ -z $btd_scale ] ; then
            # count zeros and adjust for them
            case $x_btd_frac in
                0*) zeros=${x_btd_frac%%1*} z_len=${#zeros}
                    rnd=$(( ${#zeros} % 4 )) z_len=$(( $z_len + (4 - $rnd) + 4 ))
                    btd_auto_scale=$(( ($z_len / 4) + 2 ))
                ;;
                *) btd_auto_scale=$(( (${#x_btd_frac} / 4) - 1 )) ;;
            esac
        else
            #btd_auto_scale=$(($btd_scale + 1))
            btd_auto_scale=$btd_scale
        fi
        [ "$debug" = 1 ] && echo btd_auto_scale=$btd_auto_scale >&2
        btd_col= col_cnt=1 ol=0
        if [ ${#x_btd_frac} -gt 24 ] ; then pows_5=1
            while [ -n "$x_btd_frac" ] ; do
                pow5=$(dec_pow_5 $pows_5) ; pows_5=$(($pows_5 + 1))
                case $x_btd_frac in 1*) out_btd_frac=$(dec_add $out_btd_frac '.'$btd_col$pow5) ;; esac
                x_btd_frac=${x_btd_frac#*?}
                if [ $col_cnt -eq 3 ] ; then 
                    btd_col='0'$btd_col ; ol=$(( $ol + 1 ))
                    [ $ol -eq 3 ] && col_cnt=0 ol=0 || col_cnt=1
                else
                    col_cnt=$(( $col_cnt + 1 ))
                fi
            done
        else btd_cnt=1
            while [ -n "$x_btd_frac" ] ; do btd_cnt=$(( $btd_cnt * 5 ))
                case $x_btd_frac in 1*) out_btd_frac=$(dec_add $out_btd_frac '.'$btd_col$btd_cnt) ;; esac
                x_btd_frac=${x_btd_frac#*?}
                if [ $col_cnt -eq 3 ] ; then 
                    btd_col='0'$btd_col ; ol=$(( $ol + 1 ))
                    [ $ol -eq 3 ] && col_cnt=0 ol=0 || col_cnt=1
                else
                    col_cnt=$(( $col_cnt + 1 ))
                fi
            done
        fi
        # if raw output is requested output it and return
        if [ "$raw_output" = '1' ] ; then
            if [ -n $out_btd_frac ] ; then
                echo $btdneg${out_btd%.*}'.'${out_btd_frac#*.}
            else
                echo $btdneg$out_btd
            fi
            return
        fi
        
        # Correct conversion errors by rounding up at the The Right Point. If the binary number was 
        # generated by dec_to_bin with auto-scaling, it will be The Right Length for rounding here.
        # Actually, any longer binary fractions will also be rounded to (~?) the last accurate digit.
        # This rounding algorithm replicates the amount of irrationality of original decimal fractions.
        
        # remove radix, truncate to auto_scale rounding size(plus adjustment)
        # prefixing fractions with a '1' protects leading zeros during addition
        [ ${#out_btd_frac} -gt 29 ] && adjust=2 || adjust=1
        [ ${#out_btd_frac} -gt 45 ] && adjust=3 || adjust=1
        out_btd_frac=$( printf '1'"%.*s" $(( $btd_auto_scale + $adjust )) ${out_btd_frac#*.} )
        case $out_btd_frac in
            # these are .5 .25 .75 .125 .375 .625
            15|125|175|1125|1375|1625) : ;; # (.875 becomes 1875)
            *1875|*6875) : ;; # 5p *75's    All other mutliples of 5 which end with these combinations 
            *4375|*9375) : ;; # 5p *75's    of digits are passed through, as is, since they are finite
            *0625|*5625) : ;; # 5p *25's    without rounding. Notice that the leading numbers of each pair
            *3125|*8125) : ;; # 5p *25's    are separated by 5 (1+5=6 4+5=9 0+5=5 4+5=9)
            # Combinations ending in 75 are like: 3x5x5x5... in 25 are like: 9x5x5x5x...
            *)  #echo size=${#out_btd_frac} 
                if [ ${#out_btd_frac} -lt 19 ] ; then
                    out_btd_frac=$(( $out_btd_frac  + 5 ))
                else
                    out_btd_frac=$( dec_add  $out_btd_frac  + 5 )
                fi
                if [ $adjust -eq 3 ] ; then
                    out_btd_frac=${out_btd_frac%???*}
                elif [ $adjust -eq 2 ] ; then
                    out_btd_frac=${out_btd_frac%??*}
                else
                    out_btd_frac=${out_btd_frac%?*}
                fi
            ;;
        esac
        # strip off leading 1
        out_btd_frac=${out_btd_frac#*1}
        # remove trailing zeros
        #while : ; do case $out_btd_frac in *0) out_btd_frac=${out_btd_frac%?*};; *) break ;; esac ;  done
        # compose full answer
        out_btd=$out_btd'.'$out_btd_frac
    fi
    echo $btdneg$out_btd
    btdneg=
}
# bin_to_dec -example usage: bin_to_dec 00101101  -or- bin_to_dec 1000101.101

# dec_to_bin - convert decimal numbers to binary
# uses no math operaters except for auto_scaling calculation, if scale is not given
# in effect, it repeatedly divides the input by 2 and writes the ouput digit-by-digit
# On the one hand, the case constructs are lookup tables, but function just like hardware circuits.
dec_to_bin(){ 
    case $1 in '-s'*|'scale='*) dtb_scale=${1#*'-s'}  dtb_scale=${dtb_scale#*'scale='} ; shift ;; esac
    case $1 in *.*|.*) dtbtxt=${1%.*} dtbtxt_frac=${1#*.} out_dtbtxt_frac= ;; *) dtbtxt=$1 dtbtxt_frac= ;; esac
    case $dtbtxt in '-'*) dtbtxtneg='-' dtbtxt=${dtbtxt#*-} ;; esac
    if [ ${#dtbtxt_frac} -eq 1 ] ; then
        auto_scale=8
    else
        auto_scale=$(( ${#dtbtxt_frac} * 4 ))
    fi
    dtb_scale=${dtb_scale:-$auto_scale} exbin= carry_state=0
    [ -z $dtbtxt ] && dtbtxt=0
    while bin_test $dtbtxt -ne 0 ; do 
        dtbtxt_mask=${dtbtxt%*?}
        case $dtbtxt in *0|*2|*4|*6|*8) exbin='0'$exbin ;;
            *)  exbin='1'$exbin
                case $dtbtxt in *1) dtbtxt=$dtbtxt_mask'0' ;; *3) dtbtxt=$dtbtxt_mask'2' ;;
                    *5) dtbtxt=$dtbtxt_mask'4' ;; *7) dtbtxt=$dtbtxt_mask'6' ;; *9) dtbtxt=$dtbtxt_mask'8' ;;
                esac ;;
        esac
        while [ -n "$dtbtxt" ] ; do 
            dtbtxt_mask=${dtbtxt#?*}
            if [ "$carry_state" = 0 ] ; then 
                case $dtbtxt in 1*|3*|5*|7*|9*) carry_state=1 ;; esac
                case $dtbtxt in
                    0*|1*) tmp=$tmp'0' ;; 2*|3*) tmp=$tmp'1' ;; 4*|5*) tmp=$tmp'2' ;;
                    6*|7*) tmp=$tmp'3' ;; 8*|9*) tmp=$tmp'4' ;;
                esac
            else 
                case $dtbtxt in 0*|2*|4*|6*|8*) carry_state=0 ;; esac
                case $dtbtxt in
                    0*|1*) tmp=$tmp'5' ;; 2*|3*) tmp=$tmp'6' ;; 4*|5*) tmp=$tmp'7' ;;
                    6*|7*) tmp=$tmp'8' ;; 8*|9*) tmp=$tmp'9' ;;
                esac
            fi
            dtbtxt=$dtbtxt_mask
        done
        dtbtxt=$tmp tmp=
    done
    exbin=$dtbtxtneg$exbin
    # convert the fractional part. If auto_scale has not been overridden, this will stop at
    # The Right Length, which is 4 times the length of the decimal fraction. Using longer
    # lengths here may(?) cause inaccurate rounding when coverting back to decimal with bin_to_dec.
    while [ ${#out_dtbtxt_frac} -lt $dtb_scale ] ; do
        new=$(dec_add '.'$dtbtxt_frac '.'$dtbtxt_frac )
        case $new in 
            '0.'*|'.'*) out_dtbtxt_frac=$out_dtbtxt_frac'0' ;; 
            *) out_dtbtxt_frac=$out_dtbtxt_frac'1' ;; 
        esac
        dtbtxt_frac=${new#*.}
    done
    # don't remove extra trailing zeros from fractions since fraction length is our 'encoding'
    [ -n "$out_dtbtxt_frac" ] && echo $exbin'.'$out_dtbtxt_frac || echo $exbin
}
# dec_to_bin -example usage: dec_to_bin 123876  -or- dec_to_bin 567.432

# for conversion from binary to decimal, we need decimal addition of arbitrary length
# this function only adds absolute values -it doesn't support negative values
# dec_add -add 2 or more decimal numbers, including fractions
dec_add(){ U=$1 carry_da=0 ; shift 
    while [ $1 ] ; do
        # separate integer and fractional parts, if present
        case $U in .?*) U_int= U_frac=${U#*.} ;; *?.?*) U_int=${U%.*} U_frac=${U#*.} ;; *) U_int=${U} U_frac= ;; esac
        case $1 in .?*) V_int= V_frac=${1#*.} ;; *?.?*) V_int=${1%.*} V_frac=${1#*.} ;; *) V_int=${1} V_frac= ;; esac
        # pad trailing fraction parts till equal length, if present
        while [ ${#U_frac} -lt ${#V_frac} ] ; do U_frac=$U_frac'0' ; done
        while [ ${#V_frac} -lt ${#U_frac} ] ; do V_frac=$V_frac'0' ; done
        f_len=${#U_frac}    # determine the fraction length
        # front-pad integer parts till equal length
        while [ ${#U_int} -lt ${#V_int} ] ; do U_int='0'$U_int ; done
        while [ ${#V_int} -lt ${#U_int} ] ; do V_int='0'$V_int ; done
        # recompose the two numbers without the radix
        U=$U_int$U_frac  V=${V_int}${V_frac}
        while [ -n "$U" ] ; do  # addition from right to left
            Umask=${U%?*} A=${U#*$Umask} U=$Umask ; Vmask=${V%?*} B=${V#*$Vmask} V=$Vmask
            r_tmp=$(( $A + $B + $carry_da )) carry_da=0
            [ ${#r_tmp} -eq 2 ] && r_tmp=${r_tmp#*?} carry_da=1 ; res_da=$r_tmp$res_da r_tmp=0
        done
        [ $carry_da -eq 1 ] && res_da='1'$res_da ; carry_da=0 r= A= B= r_tmp=
        # separate the integer part from the fraction, if present
        while [ ${#res_da} -gt $f_len ] ; do
            maske=${res_da#*?} ; res_da_int=${res_da_int}${res_da%$maske*} ; res_da=$maske
        done # what's left is the fraction
        res_da_frac=$res_da # always remove leading zeros from res_da_int and res_da_frac, except for one
        while : ; do case $res_da_int in '0'?*) res_da_int=${res_da_int#*?} ;; *) break ;; esac ; done
        while : ; do case $res_da_frac in *?'0') res_da_frac=${res_da_frac%?*} ;; *) break ;; esac ; done
        [ $f_len -eq 0 ] && U=$res_da_int || U=$res_da_int'.'$res_da_frac
        res_da= res_da_int= res_da_frac=
        shift
    done
    echo $U
}
#dec_add  -example usage: dec_add 4 27  -or- dec_add 8 43 22 ... 

# return (in decimal) a single power of 5 or a list, ascending or descending, up to or down from a given power
# instead of multiplying by 5 each time, we keep a buffer of the last three results, and calculate the next
# result by adding the (current result) to the (third-last result * 100) -which is done by padding with 2 0's
# uses shell math operators for the small stuff, but dec_add will go forever if you want really big powers
dec_pow_5(){ case $1 in up) up=1 listit=1 ; shift ;; dn) dn=1 listit=1 ; shift ;; *) listit=0 ;; esac 
    pows5_idx=$1
    case $pows5_idx in 0) echo 1 ; return;; 1) echo '5' ; return;; esac # easy out for easy answers
    # otherwise, powers up to 5^27 can be done with shell math 
    last=5 po5_cnt=1 po5_list=5
    while [ $po5_cnt -lt $pows5_idx ] ; do
        current_po5=$(($last * 5 )) ; last=$current_po5 ; po5_cnt=$(( $po5_cnt + 1 ))
        if [ "$listit" = 1 ] ; then
            [ "$dn" = 1 ] && po5_list="$current_po5 $po5_list" || po5_list="$po5_list $current_po5"
        fi
        # if the request is bigger than 5^27, break here and continue below
        [ $po5_cnt = 27 ] && break
    done
    if [ $pows5_idx -lt 28 ] ; then
        [ "$listit" = 1 ] && echo $po5_list || echo $current_po5
        return
    else # for larger powers, these jump-in values would be the last three remembered values:
        po5_cnt=27 third=298023223876953125 second=1490116119384765625 last=7450580596923828125
        while [ $po5_cnt -lt $pows5_idx ] ; do
            current_po5=$(dec_add $last $third'00') # push the new value to the buffer
            third=$second second=$last last=$current_po5
            if [ "$listit" = 1 ] ; then
                [ "$dn" = 1 ] && po5_list="$current_po5 $po5_list" || po5_list="$po5_list $current_po5"
            fi
            po5_cnt=$(( $po5_cnt + 1 ))
        done
    fi
    [ "$listit" = 1 ] && echo $po5_list || echo $current_po5
}
# dec_pow_5 -example usage: dec_pow_5 7 -or- dec_pow_5 up/dn 5

# d2d_ops accepts two decimal inputs separated by the operators + - x /. Inputs are 
# converted to binary, the operation is performed and the result is converted back to decimal
d2d_ops(){ case $1 in 'scale='*|'-s'*) d2d_scale=${1#=*} d2d_scale=${1#-s*}  ; shift ;; esac
    case $1 in *.*) d2d_a_i=${1%.*} d2d_a_frac='.'${1#*.} ;; *) d2d_a_i=$1 d2d_a_frac='.0' ;;  esac
    case $3 in *.*) d2d_b_i=${3%.*} d2d_b_frac='.'${3#*.} ;; *) d2d_b_i=$3 d2d_b_frac='.0' ;; esac
    d2d_op=$2
    # equalize fraction lengths for best results and recombine
    while [ ${#d2d_a_frac} -lt ${#d2d_b_frac} ] ; do d2d_a_frac=$d2d_a_frac'0' ; done
    while [ ${#d2d_b_frac} -lt ${#d2d_a_frac} ] ; do d2d_b_frac=$d2d_b_frac'0' ; done
    d2d_a=$d2d_a_i$d2d_a_frac  d2d_b=$d2d_b_i$d2d_b_frac
    # if scale is not given, set to match the fraction length
    [ -z "$d2d_scale" ] && d2d_scale=${#d2d_a_frac}
    b_scale=$(( $d2d_scale * 4))    # internal conversion scale is 4 times input scale
    # convert both numbers from decimal to binary
    d2d_A=$(dec_to_bin $d2d_a $b_scale) ; d2d_B=$(dec_to_bin $d2d_b $b_scale)
    # do the actual operation
    case $d2d_op in 
        '+') d2d_C=$(bin_add_sub $d2d_A + $d2d_B) ;;  '-') d2d_C=$(bin_add_sub $d2d_A - $d2d_B) ;; 
        'x'|'X') d2d_C=$(bin_mul $d2d_A $d2d_B) ;; '/') d2d_C=$(bin_div -s$b_scale $d2d_A $d2d_B) ;; 
    esac
    # convert back to decimal
    d2d_C=$(bin_to_dec $d2d_C)
    case $d2d_C in  # trim to scale, if requested
        *.*) d2d_C_int=${d2d_C%.*} d2d_C_frac=${d2d_C#*.}
            while [ ${#d2d_C_frac} -gt $d2d_scale ] ; do d2d_C_frac=${d2d_C_frac%*?} ; done
            echo $d2d_C_int'.'$d2d_C_frac ;; 
        *) echo $d2d_C ;;
    esac
}
# d2d_ops - example usage: d2d_ops 123.42 + 3876.5243  -or-  d2d_ops 8735.1263 x 123.5739

# d2d_pow  - round_trip exponentiation of decimal numbers
# d2d_pow V5
d2d_pow() { 
    case $1 in '-s'*) sig_digs=${1#-s*} ; shift ;; *) sig_digs= ;; esac
    case $1 in 
        .*) d2d_a_i=0 d2d_a_frac=${1#*.} d2d_a=$d2d_a_i'.'$d2d_a_frac ;; 
        *.*) d2d_a_i=${1%.*} d2d_a_frac=${1#*.} d2d_a=$d2d_a_i'.'$d2d_a_frac ;;
        *) d2d_a=$1 d2d_a_i=$d2d_a d2d_a_frac= ;; 
    esac
    case $2 in '-'*) d2d_neg='-' d2d_pow=${2#*-};; *) d2d_pow=$2 d2d_neg= ;; esac
    #convert power to binary
    d2dpow=$(debug=1 dec_to_bin $d2d_pow)
    # set the base precision
    if [ -z "$d2d_a_frac" ] ; then
        d2d_prec=${#d2d_a}
    elif [ -n "$sig_digs" ] ; then
        d2d_prec=$sig_digs
    else
        d2d_prec=${#d2d_a_frac}
    fi
    [ "$debug" = "1" ] && echo d2d_prec=$d2d_prec
    
    if [ -z "$d2d_a_frac" ] ; then
        bin_scale=0                         ### integer base
        #base_scale=$(( (7 + (($d2d_prec + 1) / 2)) * $d2d_prec ))
        base_scale=$(( (${#d2d_a} + 1) * $d2d_pow * 4 ))
        # adjust the output scale according to the power
        if [ $d2d_pow -lt 8 ] ; then
            #out_scale=$(( (($d2d_prec + 1) * $d2d_pow) + $d2d_prec ))  # under ^8
            out_scale=$(( ($d2d_prec * $d2d_pow) + $d2d_prec + 2 ))
        elif [ $d2d_pow -lt 10 ] ; then
            out_scale=$(( ($d2d_prec * $d2d_pow) + $d2d_prec + 1 ))  # under ^10
        else
            out_scale=$(( ($d2d_prec * $d2d_pow) + 2 )) # above ^10
        fi
        [ "$debug" = "1" ] && echo Integer 'bin&pow'scale=0 base_scale=$base_scale out_scale=$out_scale  >&2
    elif [ $d2d_a_i -eq 0 ] ; then
        base_scale=$(( (7 + ($d2d_prec + 1 ) / 2)  ))   ### Sub-1 scale
        bin_scale=$(( ($base_scale *  ${#d2d_a_frac}) + ($d2d_pow * 10) ))
        if [ -n "$d2d_neg" ] ; then
            case $d2d_pow in
                2|3|4) factor=13 ;;
                *) factor=11 ;;
            esac
            [ "$debug" = "1" ] && echo raising bin_scale factor=$factor
            bin_scale=$(( ($bin_scale * $factor) / 10 ))
        fi
        # standard out_scale
        out_scale=$(( ($d2d_prec * $d2d_pow) + 1 ))
        [ "$debug" = "1" ] && echo Sub-1 bin_scale=$bin_scale >&2
        [ "$debug" = "1" ] && echo Sub-1 base_scale=$base_scale out_scale=$out_scale >&2
    else
        # for larger mixed numbers, use a more generous algorithm
        base_scale=$(( (7 + ($d2d_prec + 1 ) / 2)  ))
        bin_scale=$(( ($base_scale *  ${#d2d_a_frac}) + ($d2d_pow * 10) ))
        out_scale=$(( ($d2d_prec * $d2d_pow) + 1 ))
        #out_scale=$(( $d2d_prec * $d2d_pow ))
        #out_scale=$(( ($d2d_prec * $d2d_pow) - 1 ))
        [ "$debug" = "1" ] && echo normal bin_scale=$bin_scale
        [ "$debug" = "1" ] && echo normal base_scale=$base_scale out_scale=$out_scale >&2 
        #inv_scale=$(( $base_scale * 4  ))
    fi
    
    # convert base to binary
    A_bin=$(dec_to_bin -s$bin_scale $d2d_a)
    [ "$debug" = 1 ] && echo A_bin=$A_bin >&2
    
    # do the exponentiation using the same scale
    B=$(debug=0 bin_pow_sqr -s$bin_scale $A_bin $d2dpow)
    [ "$debug" = 1 ] && echo B_pow=$B >&2
    
    if [ -n "$d2d_neg" ] ; then
        # invert the result of exponentiation
        #B_inv=$(bin_invert -s$inv_scale $B)
        
        #inv_scale=$(( ($base_scale * 33) / 10 ))
        inv_scale=$(( $base_scale * 5  ))
        ##inv_scale=$(( $base_scale * ($d2d_prec + 1)  ))
        
        B_inv=$(bin_invert -s$inv_scale $B)
        [ "$debug" = 1 ] && echo Inversion inv_scale=$inv_scale B_inv=$B_inv && echo >&2
        # if original input was under 0.1, and power is above ^4
        if [ $d2d_pow -gt 4 ] && [ $d2d_a_i -eq 0 ] ; then
            case $d2d_a_frac in 0*) out_scale=$(( ($d2d_prec * 2) + 1)) 
                [ "$debug" = 1 ] && echo shortening out_scale for accuracy under 0.1 >&2 ;; 
            esac
        fi
        B_inv_frac=${B_inv#*.} bin_zs=${B_inv_frac%%1*}
        dec_zs=$(( (${#bin_zs} * 33) / 100 ))
        [ "$debug" = 1 ] && echo B_inv_frac=$B_inv_frac leading_zs=$leading_zs dec_zs=$dec_zs >&2
        if [ $dec_zs -gt $out_scale ] ; then
            [ "$debug" = 1 ] && echo raising out_scale
            out_scale=$(( $out_scale + $dec_zs ))
        fi
        d2d_pow_out=$(bin_to_dec -s$out_scale $B_inv)
    else
        [ "$debug" = 1 ] && echo normal positive power output >&2
        nope(){
        B_frac=${B#*.} bin_zs=${B_frac%%1*}
        dec_zs=$(( (${#bin_zs} * 33) / 100 ))
        [ "$debug" = 1 ] && echo B_inv_frac=$B_inv_frac leading_zs=$leading_zs dec_zs=$dec_zs >&2
        if [ $dec_zs -gt $out_scale ] ; then
            [ "$debug" = 1 ] && echo raising out_scale
            out_scale=$(( $out_scale + $dec_zs ))
        fi
        }
        d2d_pow_out=$(bin_to_dec -s$out_scale $B)
    fi
    case $d2d_pow_out in
        *.*) d2d_pow_out_frac=${d2d_pow_out#*.}
            #if [ ${#d2d_pow_out_frac} -gt $out_scale ] ; then
            if [ ${#d2d_pow_out_frac} -gt $d2d_prec ] ; then
                d2d_pow_out_frac=${d2d_pow_out_frac%?*}
                [ "$debug" = 1 ] && echo shortening output fraction by one
            fi
            while : ; do  
                case $d2d_pow_out_frac in *?'0') d2d_pow_out_frac=${d2d_pow_out_frac%?*};; *) break ;;  esac
            done
            d2d_pow_out=${d2d_pow_out%.*}'.'$d2d_pow_out_frac
        ;;
        #*) echo $d2d_pow_out ;;
    esac
    echo $d2d_pow_out
}
#d2d_pow5


# bin_int_pow
# raise a binary number, with or without a fraction,
# to any whole-number power including negative powers
# fractional powers coming soon??
bin_int_pow(){ 
    case $1 in 'scale='*|'-s'*) bip_scale=${1#scale=*} bip_scale=${bip_scale#-s*}; shift ;; *) bip_scale= ;; esac
    bip_1=$1 bip_pow=$2
    bippy=$(bin_to_dec $bip_pow)
    case $bip_1 in *.*) bip_1_frac=${1#*.} ;; esac
    
    if [ "$bip_scale" = "a" ] ; then
        if [ -z "$bip_1_frac" ] ; then
            bip_scale='-s'$(( ${#bip_1}  + 4 ))
        else
            case $bip_1_frac in
                0*) zeros=${bip_1_frac%%1*} z_len=${#zeros}
                    rnd=$(( ${#zeros} % 4 )) z_len=$(( $z_len + (4 - $rnd) ))
                    bip_scale='-s'$(( ${#bip_1_frac}  + $(( $bippy * 4 )) + $z_len ))
                ;;
                *) bip_scale='-s'$(( ${#bip_1_frac}  + 4 )) ;;
            esac
        fi
    elif [ -n "$bip_scale" ] ; then
        bip_scale='-s'$bip_scale
    fi
    [ "$debug" = 1 ] && echo bin_int_pow: bip_scale=$bip_scale >&2
    
    case $bip_pow in '-'*) neg_pow=1 bip_pow=${bip_pow#*?} ;; esac
    
    # faster exp by squaring -but slightly less precise
    bip_1=$1 bip_pow=$2 bip_out=1
    while bin_test $bip_pow -gt 0 ; do
        case $bip_pow in 
            *0) bip_1=$(bin_mul $bip_scale $bip_1 $bip_1) ; bip_pow=${bip_pow%?*} ;; # bip_pow=$(bin_div $bip_pow 10) ;;
            *1)  bip_out=$(bin_mul $bip_scale $bip_out $bip_1) ; bip_pow=${bip_pow%?*}'0' ;;
        esac
    done
    
    if [ "$neg_pow" = 1 ] ; then
        case $bip_out in
            0.0*)bip_out=$( bin_invert $bip_out ) ;;
            *) bip_out=$( bin_div $bip_scale 0001 $bip_out ) ;;
        esac
        #echo $bip_out
        #bip_out=$( invert $bip_out $bip_scale)
    fi
    #printf ${bip_out%.*}'.'%.*s $limit ${bip_out#*.}
    echo $bip_out
}
# bin_int_pow -example usage: bin_int_pow 1000.101 -0010

# exponentiation by squaring V3
bin_pow_sqr(){ case $1 in 'scale='*|'-s'*) bip_scale=${1}; shift ;; *) bip_scale= ;; esac
    bip_1=$1 bip_pow=$2 
    bip_out=1
    while bin_test $bip_pow -gt 0 ; do
    #while [ $bip_pow -gt 0 ] ; do
        case $bip_pow in 
            *0) bip_1=$(bin_mul $bip_scale $bip_1 $bip_1) ; bip_pow=${bip_pow%?*} ;; # bip_pow=$(bin_div $bip_pow 10) ;;
            *1)  bip_out=$(bin_mul $bip_scale $bip_out $bip_1) ; bip_pow=${bip_pow%?*}'0' ;; # subtract 1, by text
        esac

    done
    echo $bip_out
}

#rdx_right2 - base-agnostic radix shifts
rdx_right(){ num=$1 rdxr=$2 rdxr_cnt=0 rdxr_out=
    case $rdxr in '0.'*) rdxr_rest=${rdxr#*.} ;; *) rdxr_out=${rdxr%.*} rdxr_rest=${rdxr#*.} ;; esac
    while [ $rdxr_cnt -lt $num ] ; do
        rdxr_cnt=$((rdxr_cnt+1)) mask=${rdxr_rest#*?} char=${rdxr_rest%$mask*}
        rdxr_out=$rdxr_out${char:-0} rdxr_rest=$mask
    done
    [ -z "$rdxr_rest" ] && echo $rdxr_out  || echo $rdxr_out'.'$rdxr_rest
}
#rdx_right2

#rdx_left - base-agnostic radix shifts
rdx_left(){ num=$1 rdxr=$2 rdxr_cnt=0 rdxr_out=
    case $rdxr in  *'.0') rdxr_rest=${rdxr%.*} ;; *) rdxr_out=${rdxr#*.} rdxr_rest=${rdxr%.*} ;; esac
    while [ $rdxr_cnt -lt $num ] ; do
        rdxr_cnt=$((rdxr_cnt+1)) mask=${rdxr_rest%?*} char=${rdxr_rest#*$mask}
        rdxr_out=${char:-0}$rdxr_out rdxr_rest=$mask
    done
    [ -z "$rdxr_rest" ] && echo '.'$rdxr_out  || echo $rdxr_rest'.'$rdxr_out
}
#rdx_left

# our version of E-notation, which unlike floating point notation has no length limits
# Normalizing numbers allows us to then do fp-like operations. Also base-agnostic
E_notate(){ norm_in=$1
    case $norm_in in 
        0.*|.*) norm_rest=${norm_in#*.} E=-1    # Sub-1 -shift right
                while : ; do 
                    norm_mask=${norm_rest#*?} norm_1st=${norm_rest%$norm_mask*}
                    case $norm_1st in  0) E=$(( E - 1 )) norm_rest=$norm_mask ;; *) break ;; esac
                done
                norm_mask=${norm_rest#*?} norm_1st=${norm_rest%$norm_mask*}
                norm_out=$norm_1st'.'$norm_mask'E'$E
        ;;
        ?.*)    norm_out=$norm_in'E0'    # already normalized -pass thru
        ;;
        *.*)    norm_in_int=${norm_in%.*} E=$(( ${#norm_in_int} - 1 ))  # larger mixed - shift left
                norm_mask=${norm_in_int#*?} norm_1st=${norm_in_int%$norm_mask*}
                norm_rest=${norm_in#*.}
                while : ; do case $norm_rest in *0) norm_rest=${norm_rest%?*} ;; *) break ;; esac ; done
                norm_out=$norm_1st'.'$norm_mask${norm_rest}'E'$E
        ;;
        ?)  norm_out=$norm_in'E0' ;;    #single-digit integer -pass thru
        *)  norm_in_int=${norm_in%.*} E=$(( ${#norm_in_int} - 1 ))  # larger integers - shift left
            norm_mask=${norm_in_int#*?} norm_1st=${norm_in_int%$norm_mask*}
            while : ; do case $norm_mask in *0) norm_mask=${norm_mask%?*} ;; *) break ;; esac ; done
            norm_out=$norm_1st'.'$norm_mask'E'$E
        ;;
    esac
    echo $norm_out
}
#E_notate

# bin_*_E functions convert natural binary to E-notation
# and do the math operations according to E-notation rules
bin_add_E(){ 
    # convert both numbers to E-notation
    aE1=$( E_notate $1 ) aE2=$( E_notate $2 )
    # get the exponents
    E1=${aE1#*E} E2=${aE2#*E}
    # strip off the E-notation
    aE1=${aE1%E*} aE2=${aE2%E*}
    E_shift=$E1
    # left-shift the number with the smaller exponent
    # and set the output shift to the larger exponent
    if [ $E1 -gt $E2 ] ; then
        aE2=$( rdx_left $(( $E1 - $E2 )) ${aE2%E*} )
    elif [ $E2 -gt $E1 ] ; then
        E_shift=$E2     # set the shift length to E2
        aE1=$( rdx_left $(( $E2 - $E1 )) ${aE1%E*} )
    fi
    # do the additition
    baE_out=$( bin_add $aE1 $aE2 )
    # shift the output
    case $E_shift in 
        -*) rdx_left ${E_shift#-*} $baE_out ;;
        *) rdx_right $E_shift $baE_out ;;
    esac
}
#bin_add_E

# as claimed, E-notation works for decimal addition
dec_add_E(){ 
    # convert both decimal numbers to E-notation
    aE1=$( E_notate $1 ) aE2=$( E_notate $2 )
    # get the exponents
    E1=${aE1#*E} E2=${aE2#*E}
    # strip off the E-notation
    aE1=${aE1%E*} aE2=${aE2%E*}
    E_shift=$E1
    # left-shift the number with the smaller exponent
    # and set the output shift to the larger exponent
    if [ $E1 -gt $E2 ] ; then
        aE2=$( rdx_left $(( $E1 - $E2 )) ${aE2%E*} )
    elif [ $E2 -gt $E1 ] ; then
        E_shift=$E2
        aE1=$( rdx_left $(( $E2 - $E1 )) ${aE1%E*} )
    fi
    # do the additition
    baE_out=$( dec_add $aE1 $aE2 )
    # shift the output
    case $E_shift in 
        -*) rdx_left ${E_shift#-*} $baE_out ;;
        *) rdx_right $E_shift $baE_out ;;
    esac
}
#dec_add_E

bin_mul_E(){ case $1 in '-s'*) bme_scale=${1}; shift ;; *) bme_scale= ;; esac
    mE1=$( E_notate $1 ) mE2=$( E_notate $2 )
    E1=${mE1#*E} E2=${mE2#*E}
    E_shift=$(( $E1 + $E2 ))
    E_prod=$( bin_mul $bme_scale ${mE1%E*} ${mE2%E*}  )
    case $E_shift in -*) rdx_left ${E_shift#*-} $E_prod ;; *) rdx_right $E_shift $E_prod ;; esac
    
}
#bin_mul_E

bin_div_E(){ case $1 in '-s'*) bde_scale=${1}; shift ;; *) bde_scale= ;; esac
    mE1=$( E_notate $1 ) mE2=$( E_notate $2 )
    E1=${mE1#*E} E2=${mE2#*E}
    E_shift=$(( $E1 - $E2 ))
    E_quotient=$( bin_div $bde_scale ${mE1%E*} ${mE2%E*}  )
    case $shift_size in -*) rdx_right $E_shift $E_quotient ;; *) rdx_left ${E_shift#*-} $E_quotient ;;  esac

}
#bin_div_E

# bin_invert2
bin_invert(){ case $1 in '-s'*) inv_scale=${1#-s*}; shift ;; *) inv_scale= ;; esac
    inv_1=$1 
    #[ "$debug" = 1 ] &&  echo bin_invert:entry $inv_scale >&2
    
    case $inv_1 in
        .0*|0.0*) inv_frac=${inv_1#*.} inv_frac_size=${#inv_frac}
            [ -z "$inv_scale" ] && inv_scale=$inv_frac_size
            #[ "$debug" = 1 ] && echo bin_invert: A inv_scale=$inv_scale inv_frac_size=$inv_frac_size >&2
            #[ "$debug" = 1 ] && echo bin_invert: frac1 $inv_frac >&2
            
            zeros=${inv_frac%%1*}
            inv_frac=${inv_1#*$zeros'1'} 
            #[ "$debug" = 1 ] && echo bin_invert: zeros=$zeros >&2
            #[ "$debug" = 1 ] && echo bin_invert: frac2 $inv_frac >&2
            
            out=$( bin_div -s$inv_scale 1 '1.'$inv_frac )
            #[ "$debug" = 1 ] && echo bin_invert: bin_div_out=$out  >&2
            #[ "$debug" = 1 ] && echo bin_invert: dec_div_out=$(bin_to_dec $out) >&2
            
            #out=$( bin_mul -s$inv_scale $out '10'$zeros )
            # instead of multiplying, shift
            shift_right=$(( ${#zeros} + 1 ))
            out=$( rdx_right $shift_right $out )
            #[ "$debug" = 1 ] && echo shift_right=$shift_right  >&2
            #[ "$debug" = 1 ] && echo zero_size=$zero_size multiplier='10'$zeros >&2
            #[ "$debug" = 1 ] && echo '10'$zeros bin_mul_out=$out >&2
        ;;
        *.*)    int_inv=${inv_1%.*} int_size=${#int_inv}
                inv_frac=${inv_1#*.} frac_size=${#inv_frac}
                #[ "$debug" = 1 ] && echo bin_invert: B int_size=$int_size frac_size=$frac_size >&2
                
                #inv_scale=$(( (($int_size + $frac_size) * 14) / 10 ))
                [ -z "$inv_scale" ] && inv_scale=$(( $int_size + $frac_size ))
                #[ "$debug" = 1 ] && echo bin_invert: scale=$inv_scale >&2
                out=$( bin_div -s$inv_scale 1 $inv_1 )
        ;;
        *)
            #[ "$debug" = 1 ] &&  echo bin_invert: C int_size=${#inv_1} >&2
            [ -z "$inv_scale" ] && inv_scale=$(( ${#inv_1} * 2 ))
            #[ "$debug" = 1 ] && echo bin_invert: scale=$inv_scale >&2
            out=$( bin_div -s$inv_scale 1 $inv_1 )
        ;;
    esac
    echo $out
    #[ "$debug" = 1 ] &&  echo 'bin_invert:exit'  >&2
}

# ones_complement -not required anywhere, yet useful
# subtraction is done by taking the two's complement of one number and adding it to the other
# the two's complement is the one's complement plus one, so we used to do this and then add one:
ones_complement(){ oc=$1
    while [ -n "$oc" ] ; do
        case $oc in 0*) ones_comp=$ones_comp'1' ;; 
            '.'*) ones_comp=$ones_comp'.' ;; *) ones_comp=$ones_comp'0' ;; esac 
        oc=${oc#*?} 
    done
    echo $ones_comp
}

# dec_pow_2 - not currently used by any other functions
# return (in decimal) a single power of 2 or a list, ascending or descending, up to or down from a given power
# Many methods for converting dec/bin/dec use decimal powers of 2. Uses shell math up to 2^62, then dec_add.
dec_pow_2(){ case $1 in up) up=1 listit=1 ; shift ;; dn) dn=1 listit=1 ; shift ;; *) listit=0 ;; esac 
    range=$1 cnt=0 base=1 dec_pow2_list=
    while [ $cnt -lt $range ] ; do cnt=$(( $cnt + 1)) base=$(( $base + $base ))
        if [ "$listit" = 1 ] ; then
            [ "$dn" = 1 ] && dec_pow2_list="$base $dec_pow2_list" || dec_pow2_list="$dec_pow2_list $base"
        fi
        # powers above 2^62 are too large for shell math, so break and continue below
        [ $cnt -eq 62 ] && break 
    done
    while [ $cnt -lt $range ] ; do cnt=$(( $cnt + 1)) base=$(dec_add $base $base)
        if [ "$listit" = 1 ] ; then
            [ "$dn" = 1 ] && dec_pow2_list="$base $dec_pow2_list" || dec_pow2_list="$dec_pow2_list $base"
        fi
    done
    [ "$listit" = 1 ] && echo $dec_pow2_list || echo $base
}
# dec_pow_2 -example usage: dec_pow_2 7 -or- dec_pow_2 up/dn 5

# check accuracy of decimal/binary/decimal conversion
back_to_back(){
    a=$(dec_to_bin $1)
    bin_to_dec $a
}

# check/compare load/run time by running 'time ./bin4sh_?.?.sh dummy_timer'
dummy_timer(){ : ;}

# list all the available functions
list() {
    for name in Main: dec_to_bin bin_to_dec bin_test bin_add_sub bin_mul bin_div \
        Advanced: bin_compare_tri bin_add bin_sub twos_complement dec_pow_5 dec_add bin_invert \
        Exponentiation: bin_int_pow bin_pow_sqr \
        Extra: ones_complement dec_pow_2 back_to_back \
        E_notation: E_notate bin_add_E bin_mul_E bin_div_E rdx_left rdx_right dec_add_E \
        dec_to_dec: d2d_ops d2d_pow ; do
        echo $name
    done
}

bin4sh_help(){
    echo "dec_to_bin    -convert decimal number to binary"
    echo "bin_to_dec    -convert binary number to decimal"
    echo "  Examples:      dec_to_bin -1234.387  -or- bin_to_dec -10011010010.011000110001"
    echo
    echo "bin_test      -test two values using familiar -lt,-gt,-eq etc."
    echo "  Example:      bin_test 1010 -gt 0101 && echo '1010 is greater than 0101'"
    echo
    echo "bin_add_sub   -add and/or subtract two or more signed or unsigned binary numbers"
    echo "  Example:      bin_add_sub 1001.1 + 0110.01 - 0010"
    echo
    echo "bin_mul       -multiply two or more signed or unsigned binary numbers"
    echo "  Example:      bin_mul 1000 0010 0100.1"
    echo
    echo "bin_div       -divide two or more signed or unsigned binary numbers"
    echo "  Example:      bin_div -s6 1010.1 0010"
    echo
    echo "d2d_ops       -take two decimal inputs, separated by one of the '+ - / x' operators,"
    echo "               convert to binary, do the operation in binary, then convert back to decimal"
    echo "  Examples:      d2d_ops 3.1416 x 2.7182 -or- d2d_ops scale=8 3.1416 / 2.7182"
    echo
    echo "For bin_div and d2d_ops, scale=? or -s? as first argument provides variable scaling."
    echo "bin_to_dec accepts an optional '-r' or 'raw' (as first option) which outputs the"
    echo "full unrounded decimal fraction output. It also supports scaling as above."
    echo "For a list of all available functions, run 'bin4sh_?.?.sh list'"
    echo "See the source code for further notes and usage examples for any of the functions."
    echo "To use bin4sh as an on-demand CLI binary calculator, source the file like this:"
    echo "source=1 . ./bin4sh_?.?.sh"
}

# execution starts here
if [ "1" != "$source" ] ; then
    cmd=$1 ; shift
    $cmd "$@" 
    exit $? 
    # exit status for use like: bin4sh_?.?.sh bin_test 1111 -gt 1110 && echo "#1 is greater than #2"
fi

# Most other bin_to_dec convertors will output -1234.386962890625... when you input: -10011010010.011000110001
# bin4sh returns: -1234.387, which matches the original input to dec_to_bin. My son, who is a Math Whiz,
# points out that -1234.386962890625 is technically 'correct'. I say: bin4sh's bin_to_dec returns the same
# degree of precision or irrationality as the original decimal input. It does this by smart-rounding the
# fraction at the furthest-right decimal place where accuracy is possible. The last digit of the
# output is not actually rounded, it is the last digit which is guaranteed to be correct. This feature
# allows bin4sh's bin_to_dec to output answers which look correct to the math layman. Using the 'raw' option
# allows the Math Whiz to have the 'correct' output. To each, his own.

