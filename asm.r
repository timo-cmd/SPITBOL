-title mincod: phase 2 translation from minimal tokens to 80386 code
-stitl description
* copyright 1987-2012 robert b. k. dewar and mark emmer.
* copyright 2012-2015 david shields

* this file is part of macro spitbol.

*     macro spitbol is free software: you can redistribute it and/or modify
*     it under the terms of the gnu general public license as published by
*     the free software foundation, either version 2 of the license, or
*     (at your option) any later version.

*     macro spitbol is distributed in the hope that it will be useful,
*     but without any warranty; without even the implied warranty of
*     merchantability or fitness for a particular purpose.  see the
*     gnu general public license for more details.

*     you should have received a copy of the gnu general public license
*     along with macro spitbol.  if not, see <http://www.gnu.org/licenses/>.

* no case folding
-case  0

*  this program takes input file in minimal token form and
*  produces assembly code for intel 80386 processor.
*  the program obtains the name of the file to be translated from the
*  command line string in host(0).  options relating to the processing
*  of comments can be changed by modifying the source.

*  in addition to the minimal token file, the program requires the
*  name of a "machine definition file" that contains code specific
*  to a particular 80386 assembler.

*  you may also specify option flags on the command line to control the
*  code generation.  the following flags are processed:
*	compress	generate tabs rather than spaces in output file
*       comments        retain full-line and end-of-line comments

*  in addition to the normal minimal register complement, one scratch
*  work register, w0 is defined.  see the register map below for specific allocations.

*  this program is based in part on earlier translators for the
*  it is based in part on earlier translators for the dec vax
*  (vms and un*x) written by steve duff and robert goldberg, and the
*  pc-spitbol translator by david shields.

*  to run under spitbol:
*       spitbol -u "<file>:<machine>[:flag:...:flag]" codlinux.spt

*	reads <file>.lex	containing tokenized source code
*       writes <file>.s         with 80386 assembly code
*	also writes <file>.err	with err and erb error messages
*       parts of n.hdr  are prepended and appended to <file>.s
*	also sets flags		to 1 after converting names to upper case
*	also reads <file>.pub	for debug symbols to be declared public

*  example:
*       spitbol -u v37:dos:compress codlinux.spt


*  revision history:

        version = 'v1.12'
	rcode = '_rc_'

*  data structures

	data('minarg(i.type,i.text)')
	data('tstmt(t.label,t.opc,t.op1,t.op2,t.op3,t.comment)')


*  keyword initialization

	&anchor = &trim	= &dump = 1
	&dump = 3
	&stlimit = 10000000


*  useful constants

	letters = 'abcdefghijklmnopqrstuvwxyz'
	ucase   = letters
	lcase   = 'abcdefghijklmnopqrstuvwxyz'
	nos     = '0123456789'
	tab	= char(9)

.if A
	asm = 'A'
.fi
.if G
	asm = 'G'
.fi

.if A
	asm_cc = ';';* comment character
	asm_d_char = 'd_char'
	asm_d_real = 'd_real'
	asm_d_word = 'd_word'
	asm_cfp_b	= 'cfp_b'
.fi
.if G
	asm_cc = '#';* comment character
	asm_d_char = '.byte'
	asm_d_real = '.double'
	asm_d_word = 'dw'
.fi

*  function definitions

*  crack parses stmt into a stmt data plex and returns it.
*  it fails if there is a syntax error.

	define('crack(line)operands,operand,char')

	define('chktrace()')
*	comregs - map minimal register names to target register names
	define('comregs(line)t,pre,word')

*  error is used to report an error for current statement

	define('a(text)')
	define('error(text)')
	define('flush()')
	define('g(text)')
	define('genz()')
	define('genaop(stmt)')
	define('genbop(stmt)')
	define('gendir(command,name)')
        define('genlab(prefix)')
        define('genrip()')
	define('getreg(iarg)')
	define('mov(i1,i2)i.src,i.dst,t.src')
	define('move(dst,src)')
	define('opds(gopc,gop1,gop2,gop3)txt')
	define('op(gopc,gop1,gop2,gop3)')
	define('opl(gopl,gopc,gop1,gop2,gop3)')
	define('genrep(op)l1,l2)')
	define('gensh(opc,reg,val)')
	define('getadr(iarg)txt,typ,pre,post')
	define('getarg(iarg)txt,typ,pre,post')
	define('getrip(iarg)txt,typ,pre,post,ent,lb,var,reg')
	define('getval(iarg)txt,typ,pre,post')
	define('ifreg(iarg)')
	define('memmem()t')
	define('outline(txt)')
	define('prcent(n)')
	define('prsarg(iarg)l1,l2')
	define('report(num,text)')
	define('ripinit()')
	define('tblini(str)pos,cnt,index,val,lastval')

*  outstmt is used to send a target statement to the target code
*  output file outfile

	define('outstmt(ostmt)label,opcode,op1,op2,op3,comment,t,stmtout')

*  readline is called to return the next non-comment line from
*  the minimal input file (infile <=> lu1).   note that it will
*  not fail on eof, but it will return a minimal end statement

	define('readline()')

	os = 'unix';	ws = '64'
	options = host(0)
	output = 'options: ' options
*	add trailing colon so always have colon after an argument
	options = options ':'
option.next
*	ignore extraneous : in list (helps with writing makefiles)
	options ':' =				:s(option.next)
	options break(':') . option ':' =	:f(options.done)

	ident(option,'unix_32')			:s(option.unix.32)
	ident(option,'unix_64')			:s(option.unix.64)
	ident(option,'osx_32')			:s(option.osx.32)
	ident(option,'xt')			:s(option.xt)
	ident(option,'it')			:s(option.it)

* here if unknown option

	output = "error: unknown option '" option "', translation ends."
	&dump = 0				:(end)

option.unix.32
	os = 'unix'; 	ws = '32'		:(option.next)
option.unix.64
	os = 'unix'; 	ws = '64'		:(option.next)
option.osx.32
	os = 'osx'; 	ws = '32'		:(option.next)
option.it
*	turn on instruction trace
	i_trace = 1				:(option.next)
option.xt
*  x_trace turns on tracing for executable instructions
	x_trace = 1				:(option.next)

options.done
	target = os '_' ws
	report(target,'target')



	filebase = "s"

*	cfp_b is bytes per word, cfp_c is characters per word
*       these should agree with values used in translator
* set target-dependent configuration parameters
	:($('config.' ws))

config.32
	cfp_b = 4
	cfp_bm1 = 3
	cfp_c = 4
	log_cfp_b = '2'
	log_cfp_c = '2'
*	op_w is instruction suffix for word-size
	op_w = 'd'
*	op_c is instruction suffix for minimal character size
	op_c = 'b'
	rel = ''
	d_word = 'dd'
	d_word = ident(asm,'A') 'dd'
	d_word = ident(asm,'G') '.long'
	m_word = 'dword '
*	suffix for opcode to indicate double word (32 bits)
	o_ =	'd'
						:(config.done)

config.64
*	cfp_b is bytes per word, cfp_c is characters per word
*       these should agree with values used in translator
	cfp_b = 8
	cfp_bm1 = 7
	cfp_c = 8
	log_cfp_b = '3'
	log_cfp_c = '3'
	op_w = 'q'
	op_c = 'b'
*	rel = 'rel '
	rel = ''
	d_word = 'dq'
	d_word = ident(asm,'G') 'dq'
	d_word = ident(asm,'G') '.quad'
	m_word = 'qword '
*	suffix for opcode to indicate quad word (64 bits)
	o_ =	'q'



config.done

*	set ab_suspend to avoid emitting 'a' and 'b' statments which flushing code buffer.
	ab_suspend = 0

*	rip_mode is needed for osx. See getval()

	rip_mode = (ident(os,'osx') 1, 0)

	report('rip', rip_mode)
	ne(rip_mode) ripinit()

*	it_limit is maximum number of calls to be generated if non-zero
	it_limit = 000
*	set it_first non-zero to skip first number of instructions that would generate trace
	it_first = 1
*	will set in_executable when in part of program where executable
*	instructions may occur
	it_exec = 0

*	it_suspend is set nonzero to temporarily disable the instruction trace.
*	it is initially nonzero so no trace can be emitted until reach code section.
	it_suspend = 1
*	set in_skip when should not insert trace code, else assembly errors result.
*	start with skip on, turn off when see first start of code.
	it_skip = 1
*	skip_on and skip_off are labels indicating the start and end,
*	respectively, of sections of the code that should not be traced,
*	usually because they contain a loop instruction that won't
*	compile if too much trace code is inserted.
	skip_on = table(50)
	skip_off = table(50)

	define('skip_init(s)on,off')		:(skip_init.end)
skip_init	s break(':') . on ':' rem . off	:f(return)
	skip_on[on] = 1
	skip_off[off] = 1			:(return)
skip_init.end

*	skip_init('start:ini03')
   	skip_init('gbcol:gtarr')
*	skip_init('gtn01:gtnvr')
*	skip_init('bpf05:bpf07')
*	skip_init('scv12:scv19')
*	skip_init('exbl1:exbl2')
*	skip_init('exbl5:expan')
*	skip_init('prn17:prn18')
*	skip_init('ini11:ini13')
*	skip_init('oex13:oexp2')
*	skip_init('oex14:oexp6')
*	skip_init('bdfc1:b_efc')
*	skip_init('sar01:sar10')
*	skip_init('srpl5:srpl8')
*	skip_init('pflu1:pflu2')
*	skip_init('prpa4:prpa5')
*	skip_init('prn17:prn18')
*	skip_init('prtvl:prtt1')
*	skip_init('trim4:trim5')
*	skip_init('prnl1:prnl2')
*	skip_init('prti1:prtmi')
*	skip_init('srpl5:srpl8')



	sectnow = 0

*	ppm_cases gives count of ppm/err statments that must follow call to
*	a procedure

	ppm_cases = table(50,,0)


	 p.comregs = break(letters) . pre span(letters) . word

*  exttab has entry for external procedures

	exttab = table(50)

*  labtab records labels in the code section, and their line numbers

	labtab = table(500)

*  for each statement, code in generated into three
*  arrays of statements:

*	astmts:	statements after opcode (()+, etc.)
*	bstmts: statements before code (-(), etc)
*	cstmts: generated code proper

	astmts = array(20,'')
	bstmts = array(10,'')
	cstmts = array(20,'')

*  genlabels is count of generated labels (cf. genlab)

	genlabels = 0

*  riplabel is count of generated rip (osx rip address mode) labels

	riplabels = 0


*  initialize variables

	labcnt = outlines = nlines = nstmts = ntarget = nerrors = 0
	lastopc = lastop1 = lastop2 =
	data_lc = 0
	max_exi = 0

*  initial patterns

*  p.csparse parses tokenized line
	p.csparse = '|' break('|') . inlabel
.	'|' break('|') . incode
.	'|' break('|') . iarg1
.	'|' break('|') . iarg2
.	'|' break('|') . iarg3
.	'|' break('|') . incomment
	'|' rem . slineno

*  dispatch table
	argcase = table(100)
	argcase[01] = .getarg.c.1;	argcase[2]  = .getarg.c.2;	argcase[3]  = .getarg.c.3;
	argcase[04] = .getarg.c.4;	argcase[5]  = .getarg.c.5;	argcase[6]  = .getarg.c.6;
	argcase[07] = .getarg.c.7;	argcase[8]  = .getarg.c.8;	argcase[9]  = .getarg.c.9;
	argcase[10] = .getarg.c.10;	argcase[11] = .getarg.c.11;	argcase[12] = .getarg.c.12;
	argcase[13] = .getarg.c.13;	argcase[14] = .getarg.c.14;	argcase[15] = .getarg.c.15;
	argcase[16] = .getarg.c.16;	argcase[17] = .getarg.c.17;	argcase[18] = .getarg.c.18;
	argcase[19] = .getarg.c.19;	argcase[20] = .getarg.c.20;	argcase[21] = .getarg.c.21;
	argcase[22] = .getarg.c.22;	argcase[23] = .getarg.c.23;	argcase[24] = .getarg.c.24;
	argcase[25] = .getarg.c.25;	argcase[26] = .getarg.c.26;	argcase[27] = .getarg.c.27

	adrcase = table(50)
	adrcase[03] = .getadr.c.3;	adrcase[04] = .getadr.c.4;	adrcase[09] = .getadr.c.9;
	adrcase[12] = .getadr.c.12;	adrcase[13] = .getadr.c.13;	adrcase[14] = .getadr.c.14
	adrcase[15] = .getadr.c.15;

.if A
	valcase = table(50)
	valcase[18] = .getval.c.18;	valcase[19] = .getval.c.19;	valcase[20] = .getval.c.20;
	valcase[21] = .getval.c.21;	valcase[22] = .getval.c.22

	riptable = table(500)
	rip_count = 0
	ripcase = table(50)
	ripcase[14] = .getrip.c.14;	ripcase[15] = .getrip.c.15;	ripcase[18] = .getrip.c.18;
	ripcase[19] = .getrip.c.19;	ripcase[20] = .getrip.c.20;	ripcase[21] = .getrip.c.21;
	ripcase[22] = .getrip.c.22
.fi
.if G

	valtable = table(100)
.fi

*  pifatal maps minimal opcodes for which no a code allowed
*  to nonzero value. such operations include conditional
*  branches with operand of form (x)+

	pifatal = tblini(
.	'aov[1]beq[1]bne[1]bge[1]bgt[1]bhi[1]ble[1]blo[1]'
.	'blt[1]bne[1]bnz[1]ceq[1]cne[1]mfi[1]nzb[1]zrb[1]')

*	trace not working for mvc (x32/x64)

	is_executable = table(100)
	s =
+       'add adi adr anb aov atn bct beq bev bge bgt bhi ble blo blt bne bnz bod brn bri bsw btw '
+	'bze ceq chk chp cmb cmc cmp cne csc cos ctb ctw cvd cvm dca dcv eti dvi dvr erb esw etx flc '
+       'ica icp icv ieq ige igt ile ilt ine ino iov itr jmp jsr lch lct lcp lcw ldi ldr lei lnf lsh lsx '
+	'mcb mfi mli mlr mnz mov mti mvw mwb ngi eti ngr nzb orb plc prc psc req rge rgt rle rlt rmi rne '
+	'rno rov rsh rsx rti rtn sbi sbr sch scp sin sqr ssl sss sti str sub tan trc wtb xob zer zgb zrb'

*	don't trace mvc as doing so causes just 'end' to fail. sort out later. (ds 01/09/13)

is_exec.1
	s len(3) . opc ' ' =			:f(is_exec.2)
	is_executable[opc] = 1			:(is_exec.1)
is_exec.2

-stitl main program
*  here follows the driver code for the "main" program.


*  loop until program exits via g.end

*  opnext is invoked to initiate processing of the next line from
*  readline.
*  after doing this, opnext branches to the generator routine indicated
*  for this opcode if there is one.
*  the generators all have entry points beginning
*  with "g.", and can be considered a logical extension of the
*  opnext routine.  the generators have the choice of branching back
*  to dsgen to cause the thisstmt plex to be sent to outstmt, or
*  or branching to dsout, in which case the generator must output
*  all needed code itself.

*  the generators are listed in a separate section below.


*  get file name


* get definition file name following token file name, and flags.

*	filebase ? break(';:') . filebase len(1) (break(';:') | rem) . target
*+		((len(1) rem . flags) | '')
*	$replace(target,lcase,ucase) = 1

* parse and display flags, setting each one's name to non-null value (1).

 :(flgs.skip)
flgs	flags ? ((len(1) break(';:')) . flag len(1)) |
+	 ((len(1) rem) . flag) =			:f(flgs2)
	flag = replace(flag,lcase,ucase)
        output = "  flag: " flag
	$flag = 1					:(flgs)

flgs.skip
flgs2

* various constants

	tab = char(9)
        comment.delim = ';'

	arg_w0 = minarg(8,'w0')
	arg_xl = minarg(7,'xl')
	arg_xr = minarg(7,'xr')

*  branchtab maps minimal opcodes 'beq', etc to desired
*  target instruction

	branchtab = table(10)
	branchtab['beq'] = 'je'
	branchtab['bne'] = 'jne'
	branchtab['bgt'] = 'ja'
	branchtab['bge'] = 'jae'
	branchtab['ble'] = 'jbe'
	branchtab['blt'] = 'jb'
	branchtab['blo'] = 'jb'
	branchtab['bhi'] = 'ja'

*  optim.tab flags opcodes capable of participating in or optimization
*		in outstmt routine

	optim.tab = table(10)
	optim.tab<"and"> = 1
	optim.tab<"add"> = 1
	optim.tab<"sub"> = 1
	optim.tab<"neg"> = 1
	optim.tab<"or"> = 1
	optim.tab<"xor"> = 1
	optim.tab<"shr"> = 1
	optim.tab<"shl"> = 1
	optim.tab<"inc"> = 1
	optim.tab<"dec"> = 1


*  ismem is table indexed by operand type which is nonzero if
*  operand type implies memory reference.

	ismem = array(30,0)
	ismem<3> = 1; ismem<4> = 1; ismem<5> = 1
	ismem<9> = 1; ismem<10> = 1; ismem<11> = 1
	ismem<12> = 1; ismem<13> = 1; ismem<14> = 1
	ismem<15> = 1

*  regmap maps minimal register name to target machine
*  register/memory-location name.

	regmap = table(30)
	s = 'xlXLxrXRxsXSxtXTwaWAwbWBwcWCw0W0iaIAcpCP'
regmap.loop
	s len(2) . min len(2) . reg =		:f(regmap.done)
	regmap[min] = reg			:(regmap.loop)
regmap.done

	w0 = "JUNK_W0"

*  quick reference:
	reg.xl = regmap['xl']
	reg.xr = regmap['xr']
	reg.xs = regmap['xs']
	reg.w0 = regmap['w0']
	reg.wa = regmap['wa']
	reg.wb = regmap['wb']
	reg.wc = regmap['wc']
	reg.cp = regmap['cp']
	reg.ia = regmap['ia']

* reglow maps register to identify target, so
* can extract 'l' part.
	reglow = table(4)
.if A
	reglow['wa'] = 'WA_L'
	reglow['wb'] = 'WB_L'
	reglow['wc'] = 'WC_L'
	reglow['w0'] = 'W0_L'
.fi
.if G
	reglow['wa'] = '%cl'
	reglow['wb'] = '%bl'
	reglow['wc'] = '%dl'
	reglow['w0'] = '%al'
.fi

* real_op maps minimal real opcode to machine opcode
	real_op = table(10)
	real_op['adr'] = 'fadd'
	real_op['atn'] = 'fpatan'
	real_op['chp'] = 'frndint'
	real_op['cos'] = 'fcos'
	real_op['dvr'] = 'fdiv'
	real_op['ldr'] = 'fld'
	real_op['mlr'] = 'fmul'
	real_op['ngr'] = 'fchs'
	real_op['sbr'] = 'fsub'
	real_op['sin'] = 'fsin'
	real_op['sqr'] = 'fsqrt'
	real_op['str'] = 'fst'

*  other definitions that are dependent upon things defined in the
*  machine definition file, and cannot be built until after the definition
*  file has been read in.

*  p.outstmt examines output lines for certain types of comment contructions
	fillc	  = (ident(compress) " ",tab)
	p.outstmt = (break(fillc) . label span(fillc)) . leader
+			comment.delim rem . comment
	p.alltabs = span(tab) rpos(0)

*  strip end of comments if y

	strip_comment = (differ(comments) 'n', 'y')

        output = ~input(.infile,1,'s.lex') "no input file"	:s(end)

inputok



*  associate output files.

        output = ~output(.outfile,2,'s.s') "no output file"	:s(end)
outputok


* open file for compilation of minimal err and erb messages

        output = ~output(.errfile,3,'s.err') "no error file"	:s(end)
err_ok
* 	&dump = 0

*  read in .equ file with value for symbols defined by equ opcode (this is really only needed for gas)
	output = ~input(.equfile,6,'s.equ') 'cannot open equ file'	:s(end)
	equ_value = table(1000)
equ.copy
	line = equfile				:f(equ.end)
	line break(' ') . key ' ' rem . val
	equ_value[key] = val			:(equ.copy)
equ.end
	endfile(6)
.fi

*  read in pub file if it exists.  this contains a list of symbols to
*  be declared public when encountered.

	pubtab = table(2)
	input(.pubfile,5, filebase ".pub")		:f(nopub)
	pubtab = table(101)
pubcopy	line = pubfile				:f(pubend)
	pubtab[line] = 1			:(pubcopy)
pubend	endfile(5)
nopub

						:(dsout)
  &trace = 2000
  &ftrace = 1000
*  &profile = 1
dsout
opnext	thisline = readline()
	crack(thisline)				:f(dsout)
	op_ = incode '_'

* append ':' after label if in code or data.

* output label of executable instruction immediately if there is one,
* as it simplifies later processing, especially for tracing.
	ident(inlabel)				:s(opnext.1)
	thislabel = inlabel (differ(inlabel) ge(sectnow,3) ':',)
* keep the label as is is not in executable code
	lt(sectnow,5)				:s(opnext.1)
* here if in code, so output label now
* defer label processing for ent to allow emission of alignment ops for x86.
	ident(incode,'ent')			:s(opnext.1)
	outline(thislabel)
* set lastlabel so can check to avoid emitting duplicate label definitions
	lastlabel = thislabel
* clear out label info once generated
	label = thislabel =
opnext.1
	thislabel = inlabel (differ(inlabel) ge(sectnow,3) ':',)
	i1 = prsarg(iarg1)
	i2 = prsarg(iarg2)
	i3 = prsarg(iarg3)
.if A
	tcomment = comregs(incomment) '} ' incode ' ' i.text(i1) ' '
.		i.text(i2) ' ' i.text(i3)
.fi
.if G
	tcomment = comregs(incomment) '} ' incode ' ' i.text(i1) ' '
.		i.text(i2) ' ' i.text(i3)
.fi
	argerrs = 0
	differ(it_trace) ge(sectnow,5) eq(it_suspend) chktrace()
	ge(sectnow,5) chktrace()
						:($('g.' incode))
*  here if bad opcode
ds01	error('bad op-code')			:(dsout)

*  generate tokens.

ds.typerr
	error('operand type zero')		:(dsout)
-stitl comregs(line)t,pre,word
comregs
	line p.comregs =			:f(comregs1)
	word = eq(size(word),2) differ(t = regmap[word]) t
	comregs = comregs pre word		:(comregs)
comregs1 comregs = comregs line			:(return)
-stitl crack(line)
*  crack is called to create a stmt plex containing the various parts  of
* the minimal source statement in line.  for conditional assembly ops,
* the opcode is the op, and op1 is the symbol.  note that dtc is handled
*  as a special case to assure that the decomposition is correct.

*  crack prints an error and fails if a syntax error occurs.

crack   nstmts  = nstmts + 1
	op1 = op2 = op3 = typ1 = typ2 = typ3 =
	line    p.csparse			:s(return)
*  here on syntax error

	error('source line syntax error')	:(freturn)
-stitl a(text)
* emit text if using asm
a
.if A
	a = text
.fi
						:(return)
-stitl error(text)
*  this module handles reporting of errors with the offending
*  statement text in thisline.  comments explaining
*  the error are written to the listing (including error chain), and
*  the appropriate counts are updated.

error   outline('* *???* ' thisline)
	outline('*       ' text)
.	          (ident(lasterror),'. last error was line ' lasterror)
	lasterror = outlines
	le(nerrors = nerrors + 1, 10)		:s(dsout)
        output = 'too many errors, quitting'  :(end)

-stitl g(text)
* emit text if using gas
g
.if G
	g = text
.fi
						:(return)
-stitl genaop(stmt)
genaop

	astmts[astmts.n = astmts.n + 1] = stmt	:(return)
-stitl genbop(stmt)
genbop
	bstmts[bstmts.n = bstmts.n + 1] = stmt	:(return)

-stitl genlab(prefix)
*  generate unique labels for use in generated code
genlab	genlab = (differ(prefix) prefix,'')  '_' lpad(genlabels = genlabels + 1,4,'0') :(return)

-stitl genrip()
*  generate unique labels for use in generated code
genrip	genrip = 'r_' lpad(riplabels = riplabels + 1,4,'0') :(return)

-stitl opl(gopl,gopc,gop1,gop2,gop3)
*  generate operation with label
opl	cstmts[cstmts.n = cstmts.n + 1] =
.		tstmt(gopl,gopc,gop1,gop2,gop3)	:(return)

-stitl op(gopc,gop1,gop2,gop3)
*  generate operation with no label
op   opl(,gopc,gop1,gop2,gop3)            :(return)

-stitl getreg(iarg)
*  return register associated with argument for types 7-11
getreg
						:($('getreg.' i.type(iarg)))
getreg.7	
getreg.8	 getreg = i.text(iarg)			:(return)

getreg.9
getreg.10	getreg = substr(i.text(iarg),2,2)	:(return)

getreg.11	getreg = substr(i.text(iarg),3,2)	:(return)

-stitl mov(i1,i2)i.src,i.dst,t.src
*   translate 'mov' instruction
mov
*  perhaps change mov x,(xr)+ to
*	mov ax,x; stows

*  perhaps do  mov (xl)+,wx as
*	lodsw
*	xchg ax,tx
*  and also mov (xl)+,name as
*	lodsw
*	mov name,reg.w0
*  need to process memory-memory case
*  change 'mov (xs)+,a' to 'pop a'
*  change 'mov a,-(xs)' to 'push a'
        i.src = i2; i.dst = i1
	t.src = i.text(i.src); t.dst = i.text(i.dst)
	ident(t.src,'(xl)+')			:s(mov.xlp)
	ident(t.src,'(xt)+')			:s(mov.xtp)
	ident(t.src,'(xs)+')			:s(mov.xsp)
	ident(t.dst,'(xr)+')			:s(mov.xrp)
	ident(t.dst,'-(xs)')			:s(mov.2)
	memmem()
	move(getarg(i1),getarg(i2))		:(return)
mov.xtp
mov.xlp
.if A
	ident(t.dst,'(xr)+') op('movs_w')	:s(return)
	op('lods_w')
.fi
.if G
	ident(t.dst,'(xr)+') op('movs' (eq(ws,32) 'd', 'q')) :s(return)
	op('lods' (eq(ws,32) 'd', 'q'))
.fi
	move(getarg(i.dst),reg.w0)		:(return)
	ident(t.dst,'-(xs)') op('push',reg.w0)	:s(return)

mov.xsp
.if A
	ident(t.dst,'(xr)+')		:s(mov.xsprp)
	op('pop',getarg(i.dst))		:(return)
.fi
.if G
	ident(t.dst,'(xr)+')		:s(mov.xsprp)
	op('pop',getarg(i.dst))		:(return)
.fi

mov.xsrp
.if A
	op('pop',reg.w0)
	op('stos_w')				:(return)
.fi
.if G
	op('pop',reg.w0)
	op('stos' (eq(ws,32) 'd', 'q'))	:(return)
.fi

mov.xrp
	move(reg.w0,getarg(i.src))
.if A
	op('stos_w')				:(return)
.fi
.if G
	op('stos' (eq(ws,32) 'd','q'))	:(return)
.fi

mov.2
	op('push',getarg(i.src))		:(return)

-stitl move(dst,src)
move
.if A
	op('mov',dst,src)			:(return)
.fi
.if G
	op('mov' o_,src,dst)			:(return)
.fi

-stitl opds(gopc,gop1,gop2,gop3)
*  generate operation with no label, with dest/src switched if using gas
*  asm uses 'intel' syntax, with destination followed by source
*  gas use 'att' syntax, with source followed by destination
*  opds does the switching if compiling for gas.
opds
.if G
	ident(gopc,'add')			:s(opds.switch)
	ident(gopc,'mov')			:s(opds.switch)
	ident(gopc,'sub')			:s(opds.switch)
						:(opds.emit)
opds.switch
	tmp = gop1; gop1 = gop2; gop2 = tmp
	gopc = gopc o_
opds.emit
.fi
	opl(,gopc,gop1,gop2,gop3)            :(return)

-stitl	gensh(opc,reg,val)
gensh
*  if the shift count is constant, then just do the shift. Otherwise, save WA, which corresponds
*  to %cl, load the shift count to that register, do the shift. Then restore WA, unless it was the
*  register to be shifted

*  gensh currently only used by gas. Should have mainline use it too. TBSL
	opc = (ident(opc,'lsh') 'sal', 'sar')
*  get value if shift count is constant defined in equ statement
	val = differ(equ_value[val]) equ_value[val]
	integer(val) op(opc, '$' val, reg)	:s(return)
	ident(reg,reg.wa)			:s(gensh.wa)
*  here if register is NOT WA, so push/restore WA
	op('push',reg.wa)
	op('mov',val,reg.wa)
	op(opc, '%cl',reg)
	op('pop',reg.wa)			:(return)
reg.wa
*  here if shifting WA. Move to W0, then use WA to get shift count, shift W0, and move result back to WA
	mov(reg.wa.reg.w0)
	mov(val,reg.wa)
	op(opc,'%cl',reg.w0)
	op('mov',reg.w0,reg.wa)
						:(return)
-stitl getarg(iarg)
getarg
*	imem is null to generate memory reference, otherwise just get
*	address for use in 'lea' instruction.
.if A
	pre = 'm('
	post = ')'
.fi
.if G
	base = disp = indx = scale =

.fi
	txt = i.text(iarg)
	typ = i.type(iarg)
	it_suspend = 1
	eq(typ)					:f($(argcase[typ]))
	getarg = txt				:(getarg.done)

* int
getarg.c.1 getarg = txt				:(getarg.done)

* dlbl
getarg.c.2 getarg = txt				:(getarg.done)

* wlbl, clbl
getarg.c.3
getarg.c.4 
.if A
	getarg = pre txt post		:(getarg.done)
.fi
.if G
	disp = txt				:(getarg.mem)
.fi
* elbl, plbl
getarg.c.5
getarg.c.6 getarg = txt				:(getarg.done)

* w,x, map register name
getarg.c.7
getarg.c.8
	getarg = regmap[txt]			:(getarg.done)

* (x), register indirect
getarg.c.9
.if A
	txt len(1) len(2) . typ
	typ = regmap[typ]
	getarg = pre typ post
						:(getarg.done)
.fi
.if G
	txt len(1) len(2) . indx		:(getarg.mem)
.fi
* (x)+, register indirect, post increment
* use lea reg,[reg+cfp_b] unless reg is esp, since it takes an extra byte.
* actually, lea reg,[reg+cfp_b] and add reg,cfp_b are both 2 cycles and 3 bytes
* for all the other regs, and either could be used.
getarg.c.10
.if A
	txt = substr(txt,2,2)
	t1 = regmap[txt]
	getarg = pre t1 post
	(ident(txt,'xs') genaop(tstmt(,'add',t1,'cfp_b'))) :s(getarg.done)
	genaop(tstmt(,'lea',t1,'a(' t1 '+cfp_b)')):(getarg.done)
.fi
.if G
	indx = substr(txt,2,2)
	genaop(tstmt(,'add','$' cfp_b, regmap[indx])) :(getarg.mem)
.fi

*  -(x), register indirect, pre decrement
getarg.c.11
.if A
	t1 = regmap[substr(txt,3,2)]
	getarg = pre t1 post
	genbop(tstmt(,'lea',t1,'a(' t1 '-cfp_b)')) :(getarg.done)
.fi
.if G
	indx = substr(txt,3,2)
	genbop(tstmt(,'sub','$' cfp_b, regmap[indx])) 	:(getarg.mem)
.fi

* int(x)
* dlbl(x)
getarg.c.12
getarg.c.13
.if A
	txt break('(') . t1 '(' len(2) . t2
	getarg = pre  '(cfp_b*' t1 ')+' regmap[t2]  post
						:(getarg.done)
.fi
.if G
	txt break('(') . disp '(' len(2) . indx
	disp = cfp_b * equ_value[disp]
	base = indx
	indx = 					:(getarg.mem)
.fi
*  name(x), where name is in working section
getarg.c.14
getarg.c.15
.if A
	getarg = ne(rip_mode)	getrip(iarg)		:s(return)
	txt break('(') . t1 '(' len(2) . t2
	getarg = pre    t1 '+'  regmap[t2] 	post
						:(getarg.done)
.fi
.if G
	txt break('(') . disp '(' len(2) . indx	:(getarg.mem)
.fi
* signed integer
getarg.c.16 getarg = txt			:(getarg.done)

* signed real
getarg.c.17 getarg = txt			:(getarg.done)

.if A
getarg.c.18
getarg.c.19
getarg.c.20
getarg.c.21
getarg.c.22
	getarg = getval(iarg)			:(getarg.done)
.fi
.if G
*  =dlbl
getarg.c.18	
	getarg = '$' substr(txt,2)		:(getarg.done)
	
*  *dlbl
getarg.c.19
	getarg  = '$'  cfp_b '*' substr(txt,2)	:(getarg.done)

*  =name (data section)
getarg.c.20
getarg.c.21
        getarg = '$' substr(txt,2)	
						:(getarg.done)
	op('lea',reg.w0,substr(txt,2))
	getarg = reg.w0				:(getarg.done)

*  =name (program section)
getarg.c.22

       getarg = '$' substr(txt,2)		:(getarg.done)

.fi

*  pnam, eqop
getarg.c.23
getarg.c.24 
	getarg = txt			:(getarg.done)

* ptyp, text, dtext
getarg.c.25
getarg.c.26
getarg.c.27 getarg = txt			:(getarg.done)
getarg.done
	it_suspend = 0
*	ne(x_trace) outline('; arg ' typ ':' txt   ' -> ' getarg)
						:(return)
.if G
getarg.mem
	getarg = differ(base) disp '(' regmap[base] ')'		:s(getarg.done)	
	getarg = ident(indx) disp 				:s(getarg.done)
	getarg = ident(scale) ident(disp) '(' regmap[indx] ')'	:s(getarg.done)
	getarg = differ(disp) disp '(,' regmap[indx] ',' scale ')'	:(getarg.done)

.fi
-stitl getadr(iarg)
getadr
.if A
*	similar to getarg, but gets effective address
*	this procedure only called if operand is
*	ops: 3,4,9,12,13,14,15
*	imem is null to generate memory reference, otherwise just get
*	address for use in 'lea' instruction.
	pre = 'a('
	post = ')'
.fi
.if G
*	similar to getarg, but gets effective address
*	this procedure only called if operand is in range 3-4 or 9-15
*	it generates code to load effective address of the argument to w0

.fi
	txt = i.text(iarg)
	typ = i.type(iarg)
	eq(typ)					:f($(adrcase[typ]))
.if A
	getadr = txt				:(return)
.fi
.if G
						:(getadr.lit)
.fi

* wlbl, clbl
getadr.c.3
getadr.c.4
.if A
	getadr = pre txt post			:(return)
.fi
.if G
						:(getadr.lit)
.fi

* (x), register indirect
getadr.c.9
	txt len(1) len(2) . typ
.if A
	typ = regmap[typ]
	getadr = pre typ post
						:(return)
.fi
.if G
	txt = regmap[typ] 			:(getadr.done)
.fi

* int(x)
* dlbl(x)
getadr.c.12
getadr.c.13
.if A
	txt break('(') . t1 '(' len(2) . t2
	getadr = pre  '(cfp_b*' t1 ')+' regmap[t2]  post
							:(return)
.fi
.if G
	txt break('(') . t1 '(' len(2) . t2
	op('mov',regmap[t2],reg.w0)
	op('add',cfp_b '*' t1,reg.w0)		:(getadr.done)
.fi

*  name(x), where name is in working section
getadr.c.14
getadr.c.15
.if A
	txt break('(') . t1 '(' len(2) . t2
	getadr = pre    t1 '+'  regmap[t2] 	post
							:(return)
.fi
.if G
	txt break('(') . t1 '(' len(2) . t2
	op('mov',regmap[t2],reg.w0)
	op('add','$' t1,reg.w0)			:(getadr.done)
.fi

.if G
getadr.lit
*  see if have generated location for argument with same txt. Use it if so, else make new one.
	ent = valtable[txt]
	differ(ent)				:s(getadr.ent)
*  here to make new entry for generated location
	val_count = val_count + 1
	lbl = genlab('lea')
	valtable[txt] = lbl
	ent = lbl
	flush()
	it_suspend = 1
	op('.data')
	opl(lbl ':',d_word ,txt)
	op('.text')
	flush()
	it_suspend = 0
getadr.ent
*	generate reference via reg.w0 if needed
	it_suspend = 1
	flush()
	op('movq', ent ,reg.w0)
	flush()
	it_suspend = 0
						:(getadr.done)
getadr.done
	it_suspend = 0
	getadr = reg.w0
						:(return)
	
.fi
-stitl getrip(iarg)
getrip
*  return value suitable for use in rip mode (needed for osx). This requires that we
*  allocate a variable to hold the address,value. This is loaded into w0
	pre = 'm('
	post = ')'
	txt = i.text(iarg)
	typ = i.type(iarg)
	eq(typ)					:f($(ripcase[typ]))
	getrip = txt				:(getrip.done)

*  name(x), where name is in working section
getrip.c.14
getrip.c.15
	txt break('(') . var '(' len(2) . reg
*	getrip = pre    var '+'  regmap[t2] 	post
	getrip = var
						:(getrip.done)
*  *dlbl
getrip.c.19
	getrip = 'cfp_b*' substr(txt,2)		:(getrip.done)

*  =dlbl
getrip.c.18
*  =name (data section)
getrip.c.20
getrip.c.21
*  =name (program section)
getrip.c.22
        getrip =  substr(txt,2)   		:(getrip.done)

getrip.done
*  see if have generated location for argument with same txt. Use it if so, else make new one.
	ent = riptable[txt]
	differ(ent)				:s(getrip.ent)
*  here to make new entry for generated location
	rip_count = rip_count + 1
	lbl = genrip()
	riptable[txt] = lbl
	ent = lbl
	gendir('segment','data')
	opl(lbl ':',d_word,getrip)
	gendir('segment','text')
getrip.ent
*	generate reference via w0 if needed
	op('mov',reg.w0,pre ent post)
	differ(reg)	op('add',reg.w0,reg)
	getrip = reg.w0
*	outfile = ne(x_trace) '; getrip ' ent
						:(return)


-stitl getval(iarg)
getval
	pre = 'm('
	post = ')'

	txt = i.text(iarg)
	typ = i.type(iarg)
	output = lt(typ, 18) gt(typ.22) ' impossible type for getval ' typ
	getval = ne(rip_mode) getrip(iarg)	:s(return)
	eq(typ)					:f($(valcase[typ]))
	getarg = txt				:(getval.done)

*  =dlbl
getval.c.18
	getval = substr(txt,2)			:(getval.done)
getval.c.18.1
	getval = substr(txt,2)			:(getval.done)
*  *dlbl
getval.c.19
	getval = 'cfp_b*' substr(txt,2)		:(getval.done)
*  =name (data section)
getval.c.20
getval.c.21
        getval =  substr(txt,2)			:(getval.done)
*  =name (program section)
getval.c.22
        getval =  substr(txt,2)			:(getval.done)
getval.done
						:(return)

-stitl memmem()t
memmem
*  memmem is called for those ops for which both operands may be
*  in memory, in which case, we generate code to load second operand
*  to pseudo-register w0, and then modify the second argument
*  to reference this register

  eq(ismem[i.type(i1)])				:s(return)
  eq(ismem[i.type(i2)])				:s(return)
*  here if memory-memory case, load second argument
  t = getarg(i2)
  i2 = arg_w0
  move(reg.w0,t)				:(return)

-stitl outline(txt)
outline
	outlines = outlines + 1
	outfile = txt
						:(return)

-stitl prcent(n)
.if A
prcent prcent = 'prc_+cfp_b*' ( n - 1)	:(return)
.fi
.if G
prcent prcent = 'prc_+' cfp_b '*' ( n - 1)	:(return)
.fi

-stitl outstmt(ostmt)label,opcode,op1,op2,op3,comment)
*  this module writes the components of the statement
*  passed in the argument list to the formatted .s file

outstmt	label = t.label(ostmt)
* clear label if definition already emitted
	label = ident(label, lastlabel)

outstmt1
	comment = t.comment(ostmt)
* ds suppress comments
 	comment = tcomment = comments =
 	:(outstmt2)
*  attach source comment to first generated instruction
	differ(comment)				:s(outstmt2)
	ident(tcomment)				:s(outstmt2)
	comment = tcomment; tcomment =
outstmt2
	opcode = t.opc(ostmt)
	op1 = t.op1(ostmt)
	op2 = t.op2(ostmt)
	op3 = t.op3(ostmt)
*	outfile = '; opcode ' opcode
*	outfile = '; op1 ' op1
*	outfile = '; op2 ' op2
*	outfile = '; op3 ' op3
	differ(compress)			:s(outstmt3)
	stmtout = rpad( rpad(label,7) ' ' rpad(opcode,4) ' '
.		  (ident(op1), op1
.			(ident(op2), ',' op2
.				(ident(op3), ',' op3))) ,27)
.       (ident(strip_comment,'y'), ' ' (ident(comment), ';') comment)
.						:(outstmt4)
outstmt3
	stmtout = label tab opcode tab
.		  (ident(op1), op1
.		    (ident(op2), ',' op2
.		      (ident(op3), ',' op3)))
.       (ident(strip_comment,'y'), tab (ident(comment), ';') comment)

**	send text to outfile

**
outstmt4
**
**	send text to output file if not null.

*	stmtout = replace(trim(stmtout),'$','_')
	stmtout = trim(stmtout)
	ident(stmtout)				:s(return)
	outline(stmtout)
	ntarget	= ntarget + 1

*  record code labels in table with delimiter removed.
	(ge(sectnow,5) differ(thislabel))	:f(return)
	label ? break(':') . label		:f(return)
	labtab<label> = outlines		:(return)

-stitl  chktrace()
chktrace
	ident(i_trace)				:s(return)
	ne(it_suspend)				:s(return)
	clabel = inlabel
 	old_it_skip = it_skip
 	old_it_exec = it_exec
 	old_is_exec = is_exec
	it_skip = ident(inlabel,'s_aaa') 0

	is_exec = is_executable[incode]
	it_exec = differ(i_trace)  ident(inlabel, 's_aaa') 1
	it_exec = differ(i_trace) ge(sectnow,5) 1

* 	it_skip  = differ(inlabel) differ(skip_on[inlabel]) 1
* 	it_skip  = differ(inlabel) differ(skip_off[inlabel]) 0

	ne(it_skip)				:s(return)
	eq(it_exec)				:s(return)
	eq(is_exec)				:s(return)

*	ne(in_gcol)				:s(return)
chktrace.1
*	no trace if trace has been suspended

*	 only trace at label definition
*	ident(thislabel)			:s(return)

	it_count = it_count + 1

	gt(it_first) le(it_count,it_first)	:s(return)
	gt(it_limit)  gt(it_count, it_limit)	:s(return)
*	only trace an instruction once
	eq(nlines,nlast)			:s(return)
	nlast = nlines

	it_desc = '"' replace(thisline,'|',' ') '"'
.if A
	ab_suspend = 1
	gendir('segment','data')
	flush()
	lbl = genlab('it')
	opl(lbl,'d_char',it_desc)
	op('d_char','0');* string terminator
	gendir('segment','text')
	op('mov',reg.w0,lbl)
	op('mov','m(it_de)',reg.w0)
	op('call','it_')
	flush()
	ab_suspend = 0
.fi
.if G
	ab_suspend = 1
	gendir('segment','data')
	flush()
	lbl = genlab('it')
	opl(lbl ':' ,'.asciz',it_desc)
	gendir('segment','text')
	op('mov' o_,'$' lbl,'it_de')
	op('call','it_')
	ab_suspend = 0
.fi
						:(return)

-stitl prsarg(iarg)
prsarg	prsarg = minarg(0)
	iarg break(',') . l1 ',' rem . l2	:f(return)
	prsarg = minarg(convert(l1,'integer'),l2)	:(return)
-stitl readline()
*  this routine returns the next statement line in the input file
*  to the caller.  it never fails.  if there is no more input,
*  then a minimal end statement is returned.
*  comments are passed through to the output file directly.


readline readline = infile                      :f(rl02)
	nlines  = nlines + 1
	ident( readline )			:s(readline)
readline.0
	leq( substr(readline,1,1 ),';' )       	:f(rl01)
	it_skip = ident(readline,';i+') 0	:s(readline)
*	it_skip = ident(readline,';i-') 1	:s(readline)
* force skip of full line comments
	:(readline)

*  only print comment if requested.

	ident(strip_comment,'n')		:f(readline)
        readline len(1) = ';'
	outlines = outlines + 1               :(readline)

*  here if not a comment line

rl01
*  find out why need to add 2 here
*  add 2 since need to account for this line and one that will follow
	ne(x_trace) outline(asm_cc ':' outlines + 2 ':' tab readline)
					:(return)

*  here on eof

rl02    readline = '       end'
						:(rl01)
-stitl ripinit()
*  initialize rip mode, allocating the table used to save allocated locations
ripinit
	riptable = table(500)
						:(return)

-stitl tblini(str)
*  this routine is called to initialize a table from a string of
*  index/value pairs.

tblini   pos     = 0

*  count the number of "[" symbols to get an assessment of the table
*  size we need.

tin01   str     (tab(*pos) '[' break(']') *?(cnt = cnt + 1) @pos)
.						:s(tin01)

*  allocate the table, and then fill it. note that a small memory
*  optimisation is attempted here by trying to re-use the previous
*  value string if it is the same as the present one.

	tblini   = table(cnt)
tin02   str     (break('[') $ index len(1) break(']') $ val len(1)) =
.						:f(return)
	val     = convert( val,'integer' )
	val     = ident(val,lastval) lastval
	lastval = val
	tblini[index] = val			:(tin02)
-stitl generators

ifreg	ge(i.type(iarg),7) le(i.type(iarg),8)
.						:f(freturn)s(return)

g.flc
.if A
	t1 = reglow[getreg(i1)]
	t2 = genlab('flc')
*	it_suspend = 1
	op('cmp',t1,"'A'")
	op('jb', t2 )
	op('cmp',t1,"'Z'")
	op('ja', t2)
	op('add',t1,'32')
        opl(t2 ':')
*	it_suspend = 0
.fi
.if G
	
	t1 = i.text(i1)
	t2 = '%'  (ident(t1,'wa') 'c', ident(t1,reg.wb) 'b', 'd') 'l'
	t3 = genlab('flc')
	it_suspend = 1
	op('cmpb',t2,"'A'")
	op('jb', t3 )
	op('cmpb',t2,"'Z'")
	op('ja', t3)
	op('add','$32',t2)
        opl(t3 ':')
	it_suspend = 0
.fi
						:(opdone)

g.mov
	mov(i1,i2)				:(opdone)

* odd/even tests.  if w reg, use low byte of register.
g.bod
.if A
	t1 = getarg(i1)
 	t1 = eq(i.type(i1),8) reglow[getreg(i1)]
	op('test',t1,'1')
	op('jne',getarg(i2))			:(opdone)
.fi
.if G
	t1 = (eq(i.type(i1),8) reglow[getreg(i1)], getarg(i1))
	op('test',t1,'1')
	op('jne',getarg(i2))			:(opdone)
.fi

g.bev
.if A
	t1 = getarg(i1)
	t1 = eq(i.type(i1),8) reglow[getreg(i1)]
	op('test',t1,'1')
	op('je',getarg(i2))
						:(opdone)
.fi
.if G
	t1 = (eq(i.type(i1),8) reglow[getreg(i1)], getarg(i1))
	op('test',t1,'1')
	op('jne',getarg(i2))			:(opdone)
.fi

g.brn   op('jmp',getarg(i1))			:(opdone)

g.bsw
.if A
	t1 = getarg(i1)
	t2 = genlab('bsw')
	it_suspend = 1
	ident(i.text(i3))			:s(g.bsw1)
	op('cmp',t1,getarg(i2))
	op('jge',getarg(i3))
* here after default case.
g.bsw1
	ne(rip_mode)				:s(g.bsw.2)
	op('jmp', 'm(' t2 '+' t1 '*cfp_b)' ) :(g.bsw.3)
g.bsw.2
* in rip_mode, need to generate location to reference destination
	lbl = genrip()
        gendir('segment','data')
	opl(lbl,d_word,t2 )
	gendir('segment','text')
	op('mov',reg.w0,t1)
	op('sal',reg.w0,'log_cfp_b')
	op('add',reg.w0,'m(' lbl ')')
	op('jmp', reg.w0)
g.bsw.3
	gendir('segment','data')
        opl(t2 ':')
	it_suspend = 0
.fi
.if G
	t1 = getarg(i1)
	t2 = genlab('bsw')
	it_suspend = 1
	ident(i.text(i3))			:s(g.bsw1)
	op('cmp',t1,getarg(i2))
	op('jge',getarg(i3))
* here after default case.
g.bsw1	
	op('jmp','*' t2 '(,' t1 ',' cfp_b ')')
	op('.data')
        opl(t2 ':')
	it_suspend = 0
.fi
						:(opdone)

g.iff   op(d_word,getarg(i2))              :(opdone)

g.esw
	gendir('segment','text')		:(opdone)
g.ent

*  entry points are stored in byte before program entry label
*  last arg is optional, in which case no initial 'db' need be
*  issued. we force odd alignment so can distinguish entry point
*  addresses from block addresses (which are always even).

*  note that this address of odd/even is less restrictive than
*  the minimal definition, which defines an even address as being
*  a multiple of cfp_b (4), and an odd address as one that is not
*  a multiple of cfp_b (ends in 1, 2, or 3).  the definition here
*  is a simple odd/even, least significant bit definition.
*  that is, for us, 1 and 3 are odd, 2 and 4 are even.
.if A
	t1 = i.text(i1)
*       op('align',2)
	outline(tab 'align' tab '2')
	differ(t1)				:s(g.ent.1)
	outline(tab 'nop')
						:(g.ent.2)
g.ent.1
	outline(tab 'db' tab	t1)

g.ent.2
	opl(thislabel)
*  note that want to attach label to last instruction
*	t1 = cstmts[cstmts.n]
*	t.label(t1) = tlabel
*	cstmts[cstmts.n] = t1
*  here to see if want label made public
	thislabel ? rtab(1) . thislabel ':'
        (differ(pubtab[thislabel]), differ(debug)) op('global',thislabel)
.fi
.if G
	t1 = i.text(i1)
*        op('align',2)
	outline(tab '.align' tab '2')
	differ(t1)				:s(g.ent.1)
	outline(tab 'nop')
						:(g.ent.2)
g.ent.1
	outline(tab '.byte' tab	t1)

g.ent.2
	opl(thislabel)
*  note that want to attach label to last instruction
*	t1 = cstmts[cstmts.n]
*	t.label(t1) = tlabel
*	cstmts[cstmts.n] = t1
*  here to see if want label made public
	thislabel ? rtab(1) . thislabel ':'
        (differ(pubtab[thislabel]), differ(debug)) op('.global',thislabel)
.fi
	thislabel =
						:(opdone)

g.bri
.if A
	op('jmp',getarg(i1))			:(opdone)
.fi
.fi G
	op('jmp','*' getarg(i1)) :(opdone)
.fi


g.lei
.if A
	t1 = regmap[i.text(i1)]
	op('movzx',t1,'byte [' t1 '-1]' )	:(opdone)
.fi
.if G
	t1 = regmap[i.text(i1)]
	op('dec',t1)
	op('mov', '(' t1 ')', '%al')
	op('movz' (eq(ws,32) 'bl','bq'),'%al',t1) :(opdone)
.fi

g.jsr
	jsr_proc = getarg(i1)
	op('call',jsr_proc)
*	get count of following ppm statements
	jsr_count = ppm_cases[jsr_proc]
	eq(jsr_count)				:s(opdone)
	it_suspend = 1
	jsr_calls = jsr_calls +  1
	jsr_label = 'call_' jsr_calls
	jsr_label_norm = jsr_label
.if A
	op('dec','m(' rcode ')')
.fi
.if G
	op('dec' o_, rcode)
.fi
	op('js',jsr_label_norm)
	it_suspend = 0

*	generate branch around for ppms that will follow
*	take the branch if normal return (eax==0)
						:(opdone)

g.err
g.ppm

*  here with return code in rcode. it is zero for normal return
*  and positive for error return. decrement the value.
*  if it is negative then this is normal return. otherwise,
*  proceed decrementing rcode until it goes negative,and then
*  take the appropriate branch.

	t1 = getarg(i1)

*  branch to next case if rcode code still not negative.
	ident(incode,'ppm')			:s(g.ppm.loop)
	count.err =  count.err + 1
	errfile =   i.text(i1) ' ' i.text(i2)
	max.err = gt(t1,max.err) t1
						:(g.ppm.loop)

g.ppm.loop.next
	opl(lab_next ':')
 	jsr_count = jsr_count - 1
 	it_suspend = eq(jsr_count) 0
	eq(jsr_count) opl(jsr_label_norm ':') :(opdone)
g.ppm.loop
	lab_next = genlab('ppm')
.if A
	op('dec','m(' rcode ')' )
.fi
.if G
	op('dec' o_,rcode )
.fi
	op('jns',lab_next)
	ident(incode,'ppm')			:s(g.ppm.loop.ppm)

*  here if error exit via exi. set rcode to exit code and jump
*  to error handler with error code in rcode

g.ppm.loop.err
.if A
	op('mov','m(' rcode ')', +t1)
.fi
.if G
	op('mov' o_,'$' +t1,rcode, )
.fi
	op('jmp','err_')
						:(g.ppm.loop.next)
g.ppm.loop.ppm
*	check each ppm case and take branch if appropriate
	ident(i.text(i1))			:s(g.ppm.2)
	count.ppm = count.ppm + 1
	op('jmp',	getarg(i1))
						:(g.ppm.loop.next)

g.ppm.2
*  a ppm with no arguments, which should never be executed, is
*  translated to err 299,internal logic error: unexpected ppm branch
	t1 = 299
	errfile =  t1 ' internal logic error: unexpected ppm branch'
						:(g.ppm.loop.err)

g.prc

*  generate public declaration
*	t1 = thislabel
*	t1 ? rtab(1) . t1 ':'
*	op()
*	op('global',t1)
*  nop needed to get labels straight
	prc.args = getarg(i2)
	ppm_cases[thislabel] = i.text(i2)
	thislabel =
	max_exi = gt(prc.args,max_exi) prc.args
	prc.type = i.text(i1)			:($('g.prc.' prc.type))
g.prc.e
g.prc.r						:(opdone)

g.prc.n
*  store return address in reserved location
	prc.count = prc.count + 1
.if A
	op('pop', 'm(' prcent(prc.count) ')')
.fi
.if G
	op('pop', prcent(prc.count))	:(opdone)
.fi	
						:(opdone)

g.exi
        t1 = getarg(i1); t2 = prc.type; t3 = i.text(i1)
*  if type r or e, and no exit parameters, just return
 	differ(t2,'n') eq(prc.args)	op('ret')	:s(opdone)
        t3 = ident(t3) '0'
.if A
    	op('mov','m('  rcode ')',+t3)
.fi
.if G
    	op('mov' o_,'$' +t3,rcode)
.fi
	ident(t2,'n')				:s(g.exi.1)
	op('ret')				:(opdone)
g.exi.1
.if A
	op('mov',reg.w0, 'm( ' prcent(prc.count) ')' )
	op('jmp',reg.w0)
.fi
.if G
	op('mov', prcent(prc.count),reg.w0)
	op('jmp', '*' reg.w0)
.fi
						:(opdone)

g.enp   op()					:(opdone)

g.erb
	errfile =  i.text(i1) ' ' i.text(i2)
*	set rcode to error code and branch to error handler
.if A
	op('mov', 'm(' rcode ')',  +(i.text(i1)))
.fi
.if G
	op('mov' o_,  '$' +(i.text(i1)),rcode)
.fi
 	op('jmp','err_')
						:(opdone)

g.icv
.if A
	op('inc',getarg(i1))    :(opdone)
.fi
.if G
	op('inc' o_,getarg(i1))    :(opdone)
.fi

g.dcv   
.if A
	op('dec',getarg(i1))    :(opdone)
.fi
.if G
	op('inc' o_,getarg(i1))    :(opdone)
.fi

g.zer
.if A
	ident(i.text(i1),'(xr)+') op('mov',reg.w0,'0')
+		op('stos_w')			:s(opdone)
	ifreg(i1)				:s(g.zer1)
	ident(i.text(i1),'-(xs)')		:s(g.zer.xs)
	op('xor',reg.w0,reg.w0)
	op('mov',getarg(i1),reg.w0)		:(opdone)
g.zer1	t1 = getarg(i1)
	op('xor',t1,t1)			:(opdone)
g.zer.xs op('push','0')			:(opdone)
.fi
.if G
	ident(i.text(i1),'(xr)+') op('mov','$0',reg.w0)
+	  op('stos' (eq(ws,32) 'd','q'))	:s(opdone)
	ifreg(i1)				:s(g.zer1)
	ident(i.text(i1),'-(xs)')		:s(g.zer.xs)
	op('xor',reg.w0,reg.w0)
	op('mov',reg.w0,getarg(i1))		:(opdone)
g.zer1	t1 = getarg(i1)
	op('xor',t1,t1)				:(opdone)
g.zer.xs op('push','$0')			:(opdone)
.fi

g.mnz
	move(getarg(i1),reg.xs)			:(opdone)
g.ssl
g.sss
g.rtn
	op()					:(opdone)

g.add	memmem()
	opds('add',getarg(i1),getarg(i2))	:(opdone)

g.sub	memmem()
	opds('sub',getarg(i1),getarg(i2))	:(opdone)

g.ica
.if A
	op('add',getarg(i1),'cfp_b')		:(opdone)
.fi
.if G
	op('add' o_,'$' cfp_b,getarg(i1))		:(opdone)
.fi

g.dca
.if A
	op('sub',getarg(i1),'cfp_b')		:(opdone)
.fi
.if G
	op('sub' o_,'$' cfp_b,getarg(i1))	:(opdone)
.fi

g.beq
g.bne
g.bgt
g.bge
g.blt
g.ble
g.blo
g.bhi

*  these operators all have two operands, memmem may apply
*  issue target opcode by table lookup.

	memmem()
.if A
	t1 = branchtab[incode]
	op('cmp',getarg(i1),getarg(i2))
.fi
.if G
	op('cmp' o_,getarg(i2),getarg(i1))
.fi
	op(branchtab[incode],getarg(i3))
						:(opdone)

g.bnz
.if A
	ifreg(i1)				:s(g.bnz1)
        op('cmp', getarg(i1) ,'0')
.fi
.if G
	ifreg(i1)				:s(g.bnz1)
	op('xor',reg.w0,reg.w0)
        op('cmp' o_,getarg(i1) ,reg.w0)
.fi
	op('jnz',getarg(i2))
						:(opdone)
g.bnz1
	op('or',getarg(i1),getarg(i1))
	op('jnz',getarg(i2))
						:(opdone)

g.bze   ifreg(i1)				:s(g.bze1)
	op('xor',reg.w0,reg.w0);* clear w0 t0 zero
        op('cmp', getarg(i1)  ,reg.w0)
	op('jz',getarg(i2))
						:(opdone)
g.bze1
	t1 = getarg(i1)
	op('or',t1,t1)
	op('jz',getarg(i2))			:(opdone)

g.lct

*  if operands differ must emit code

	differ(i.text(i1),i.text(i2))		:s(g.lct.1)
*  here if operands same. emit no code if no label, else emit null
	ident(thislabel)			:s(opnext)
	op()					:(opdone)

g.lct.1
	move(getarg(i1),getarg(i2))	:(opdone)

g.bct
*  can issue loop if target register is cx.
	t1 = getarg(i1)
	t2 = getarg(i2)
	:(g.bct2)
.if A
	ident(t1,reg.wa)			:s(g.bct1)
.fi
.if G
	ident(t1,reg.wa)			:s(g.bct1)
.fi
g.bct2
	op('dec',t1)
	op('jnz',t2)				:(opdone)
g.bct1
	op('loop',t2)				:(opdone)

g.aov
.if A
	op('add',getarg(i2),getarg(i1))
.fi
.if G
	op('add',getarg(i1),getarg(i2))
.fi
	op('jc',getarg(i3))
						:(opdone)
g.lcp
g.lcw
g.scp
	op(op_,getarg(i1))			:(opdone)

g.icp
	op(op_)					:(opdone)
*  integer accumulator kept in memory (reg_ia)
g.ldi
g.sti
	op(op_,getarg(i1))			:(opdone)

g.adi
g.mli
g.sbi
g.dvi
	op('mov',reg.w0,getarg(i1))
	op(op_)					:(opdone)

g.rmi
	op('mov',reg.w0,getarg(i1))
*	op('mov',reg.w0,getarg(i1))
	op(op_)					:(opdone)
g.ngi
	op(op_)					:(opdone)
g.ino
g.iov
	op(op_,getarg(i1))			:(opdone)


g.ieq	jop = 'je'				:(op.cmp)
g.ige	jop = 'jge'				:(op.cmp)
g.igt	jop = 'jg'				:(op.cmp)
g.ile	jop = 'jle'				:(op.cmp)
g.ilt	jop = 'jl'				:(op.cmp)
g.ine	jop = 'jne'				:(op.cmp)
op.cmp
	op('mov',reg.w0,'m(reg_ia)')
	op('or',reg.w0,reg.w0)
	op(jop,getarg(i1))			:(opdone)

*  real operations

g.itr	op('call',op_)	:(opdone)

g.rti	op('call',op_)
	eq(i.type(i1))				:s(opdone)
*  here if label given, branch if real too large
        op('jc',getarg(i1))                 :(opdone)

g.ldr
g.str
g.adr
g.sbr
g.mlr
g.dvr
.if A
	op('lea',reg.w0,getadr(i1))
.fi
.if G
*  getadr returns ea in w0
*	it_suspend = 1
	getadr(i1)
*	it_suspend = 0
.fi
	op('call',op_)				:(opdone)


g.ngr
g.atn
g.chp
g.cos
g.etx
g.lnf
g.sin
g.sqr
g.tan
	op('call',op_)
						:(opdone)

g.rov
g.rno	op(op_,getarg(i1))			:(opdone)
*g.rno	t1 = 'jno'				:(g.rov1)
*g.rov	t1 = 'jo'
*g.rov1  op('call','ovr_')
	op(t1,getarg(i1))			:(opdone)

g.req	jop = 'je'				:(g.r1)
g.rne	jop = 'jne'				:(g.r1)
g.rge	jop = 'jge'				:(g.r1)
g.rgt	jop = 'jg'				:(g.r1)
g.rle	jop = 'jle'				:(g.r1)
g.rlt	jop = 'jl'
g.r1	
	op('call','cpr_')
.if A
	op('mov','al','byte [reg_fl]')
	op('or','al','al')
.fi
.if G
	op('mov','(reg_fl)','%al')
	op('or','%al','%al')
.fi
	op(jop,getarg(i1))			:(opdone)

g.plc
g.psc
.if A
	ne(cfp_b,cfp_c)				:s(g.plc.1)
*  last arg is optional.  if present and a register or constant,
*  use lea instead.

	t1 = getarg(i1)
	t2 = i.type(i2)
	((ifreg(i2), ge(t2,1) le(t2,2))
+	op('lea',t1,'a(cfp_f+' t1 '+' getarg(i2) ')')) :s(opdone)
	op('add',t1,'cfp_f')
	eq(i.type(i2))				:s(opdone)

*  here if d_offset_(given (in a variable), so add it in.

	op('add',t1,getarg(i2))		:(opdone)

g.plc.1
*  here for case where character size if word size
*  last arg is optional.  if present and a register or constant,
*  use lea instead.

	t1 = getarg(i1)
	t2 = i.type(i2)
	((ifreg(i2), ge(t2,1) le(t2,2))
+	op('lea',t1,'a(cfp_f+' t1 '+' 'cfp_b*' getarg(i2) ')')) :s(opdone)
	op('add',t1,'cfp_f')
	eq(i.type(i2))				:s(opdone)

*  here if d_offset_(given (in a variable), so add it in, after converting to byte count
	op('mov',reg.w0, getarg(i2))
	op('sal',reg.w0, 'log_cfp_b')

	op('add',t1,reg.w0)
.fi
.if G
*  last arg is optional.  if present and a register or constant,
*  use lea instead.

	t1 = getarg(i1)
	t2 = i.type(i2)
* TODO
	ifreg(i2)				:s(g.plc.1)
	ge(t2,1) le(t2,2)			:s(g.plc.1)
	op('add', '$cfp_f',t1)
	eq(i.type(i2))				:s(opdone)

*  here if d_offset_(given (in a variable), so add it in.

	op('add',getarg(i2),t1)		:(opdone)
g.plc.1
*	computer effefctive address of 'cfp_f+ first-argument + second-argument'

	op('mov',getarg(i2),reg.w0)
	op('add',t1,reg.w0)
	op('add','$cfp_f',reg.w0)
	op('mov',reg.w0,t1)			:(opdone)
.fi
						:(opdone)

*  always load to w0, which allows use of 'lods' if second argument is '(xr)+'

g.lch
	lch_pre = lch_post =
	src = i2; dst = i1
	s.text = i.text(src); s.type = i.type(src); s.reg = getreg(src)
	d.text = i.text(dst); d.type = i.type(dst); d.reg = getreg(dst)
	w = (eq(i.type(dst),8) 0,1);* dst is w-register
.if A
	outfile = ';lch s.text ' s.text '  s.type ' s.type '  s.reg ' s.reg
	outfile = ';lch d.text ' d.text '  d.type ' d.type '  d.reg ' d.reg '  w ' w
.fi
.if G
	outfile = '#lch s.text ' s.text '  s.type ' s.type '  s.reg ' s.reg
	outfile = '#lch d.text ' d.text '  d.type ' d.type '  d.reg ' d.reg '  w ' w
.fi
	ident(s.text,'(xl)+')			:s(g.lch.lods)


*  decrement source register if needed
	eq(s.type,11) op('dec',regmap[s.reg])

*  clear result register
	op('xor', (eq(w) getarg(dst),reg.w0), (eq(w) getarg(dst),reg.w0))

*  if target is w register, can load to it. otherwise, load to w0 and then move to x
*  do indexed load of source register

*	outfile = ';lch 1 reglow[(eq(w) d.reg, 'w0')]' reglow[(eq(w) d.reg, 'w0')]
*	outfile = ';lch,2 m_char [regmap[s.reg]])'  regmap[s.reg]
.if A
	op('mov',reglow[(eq(w) d.reg, 'w0')],'m_char [' regmap[s.reg] ']')
	ne(w) op('mov',regmap[d.reg],reg.w0)
.fi
.if G
	op('movb','(' regmap[s.reg] ')' ,reglow[(eq(w) d.reg, 'w0')])
	ne(w) op('mov',reg.w0,regmap[d.reg])
.fi

*  do post increment if needed

	eq(s.type,10)	op('inc',regmap[s.reg])
						:(opdone)
g.lch.lods
*  clear result register, do lodsb, and then move character to result register
	op('xor',reg.w0,reg.w0)
	op('lodsb')
	move(getarg(dst),reg.w0)
						:(opdone)
g.sch
	sch_pre = sch_post =
	src = i1; dst = i2
	s.text = i.text(src); s.type = i.type(src); s.reg = getreg(src)
	d.text = i.text(dst); d.type = i.type(dst); d.reg = getreg(dst)
	w = (eq(i.type(src),8) 0,1);* dst is w-register
.if A
	outfile = ';sch s.text ' s.text '  s.type ' s.type '  s.reg ' s.reg
	outfile = ';sch d.text ' d.text '  d.type ' d.type '  d.reg ' d.reg '  w ' w
.fi
.if G
	outfile = '#sch s.text ' s.text '  s.type ' s.type '  s.reg ' s.reg
	outfile = '#sch d.text ' d.text '  d.type ' d.type '  d.reg ' d.reg '  w ' w
.fi
	ident(s.text,'(xr)+')			:s(g.sch.stos)


*  decrement destination register if needed

	eq(d.type,11) op('dec',regmap[d.reg])

*  if source is x register, move it to w0, so can store character from lower part of a w register

	ne(w) move(reg.w0, regmap[s.reg])

.if A
	op('mov','m_char [' regmap[d.reg] ']', reglow[(eq(w) s.reg, 'w0')])
.fi
.if G
	op('movb', reglow[(eq(w) s.reg, 'w0')], '(' regmap[d.reg] ')') 
.fi

* increment target register if needed

	eq(d.type,10)  op('inc',regmap[d.reg])
						:(opdone)
g.sch.stos
*  move source register to w0, setting up low part, then store from w0
	move(reg.w0, regmap[s.reg])
	op('stosb')
						:(opdone)

g.csc  	ident(thislabel)			:s(opnext)
	op()					:(opdone)

g.ceq
	memmem()
	op('cmp',getarg(i1),getarg(i2))
	op('je',getarg(i3))
						:(opdone)

g.cne   memmem()
	op('cmp',getarg(i1),getarg(i2))
	op('jnz',getarg(i3))
						:(opdone)

g.cmc
.if A
	op('repe','cmps_b')
.fi
.if G
	op('repe','cmpsb')
.fi
	op('xor',reg.xl,reg.xl)
	op('xor',reg.xr,reg.xl)
	t1 = getarg(i1)
	t2 = getarg(i2)
	(ident(t1,t2) op('jnz',t1))		:s(opdone)
	op('ja',t2)
	op('jb',t1)				:(opdone)

g.trc
.if A
	op('xchg',reg.xl,reg.xr)
        opl((t1 = genlab('trc')) ':','movzx',reg.w0,'m_char [XR]')
	op('mov','al','[XL+W0]')
	op('stos' op_c)
*	op('loop',t1)
	op('dec',reg.wa)
	op('jnz',t1)
	op('xor',reg.xl,reg.xl)
	op('xor',reg.xr,reg.xr)
.fi
.if G
	op('xchg',reg.xl,reg.xr)
	labl = genlab('trc')
        opl(labl ':','movz' (eq(ws,32) 'bl', 'bq'),'(' reg.xr ')',reg.w0)
	op('add','(,' reg.xl ')',reg.w0)
	op('mov','(' reg.w0 ')', '%al')
	op('stos' op_c)
	op('dec',reg.wa)
	op('jnz',labl)
	op('xor',reg.xl,reg.xl)
	op('xor',reg.xr,reg.xr)
.fi
						:(opdone)

.if A
g.anb   op('and',getarg(i1),getarg(i2))	:(opdone)
g.orb   op('or',getarg(i1),getarg(i2))	:(opdone)
g.xob   op('xor',getarg(i1),getarg(i2))	:(opdone)
g.cmb   op('not',getarg(i1))			:(opdone)
.fi
.if G
g.anb   op('and',getarg(i2),getarg(i1))	:(opdone)
g.orb   op('or',getarg(i2),getarg(i1))	:(opdone)
g.xob   op('xor',getarg(i2),getarg(i1))	:(opdone)
g.cmb   op('not',getarg(i1))			:(opdone)
.fi

g.rsh
.if A
	op('shr',getarg(i1),getarg(i2))	:(opdone)
.fi
.if G
	gensh('shr',getarg(i1),getarg(i2))	:(opdone)
.fi

g.lsh
.if A
	op('shl',getarg(i1),getarg(i2))	:(opdone)
.fi
.if G
	gensh('shl',getarg(i1),getarg(i2))	:(opdone)
.fi

g.rsx
	error('rsx not supported')
g.lsx
	error('lsx not supported')

g.nzb	ifreg(i1)				:s(g.nzb1)
.if A
	op('cmp',getarg(i1),'0')
.fi
.if G
	op('xor',reg.w0,reg.w0)
	op('cmp',getarg(i1),reg.w0)
.fi
	op('jnz',getarg(i2))
						:(opdone)
g.nzb1
	op('or',getarg(i1),getarg(i1))
	op('jnz',getarg(i2))
						:(opdone)

g.zrb
	ifreg(i1)				:s(g.zrb1)
.if A

	op('cmp',getarg(i1),'0')
.fi
.if G
	op('xor',reg.w0,reg.w0)
	op('cmp',getarg(i1),reg.w0)
.fi
	op('jz',getarg(i2))
						:(opdone)
g.zrb1
	op('or',getarg(i1),getarg(i1))
	op('jz',getarg(i2))
						:(opdone)

g.zgb
	op('nop')				:(opdone)

g.zzz
 	op('zzz',getarg(i1))			:(opdone)

g.wtb
.if A
	op('sal',getarg(i1),'log_cfp_b')	:(opdone)
.fi
.if G
*  gas flaky on doing shifts, so just do repeated adds
	reg = getarg(i1)
	op('add',reg,reg)
	op('add',reg,reg)
	ne(ws,32) op('add',reg,reg)
						:(opdone)
.fi

g.btw
.if A
	op('shr',getarg(i1),'log_cfp_b')	:(opdone)
.fi
.if G
	gensh('shr',getarg(i1),log_cfp_b)	:(opdone)
.fi

g.mti
	ident(i.text(i1),'(xs)+')		:f(g.mti.1)
	op('pop',reg.w0)
.if A
	op('ldi_',reg.w0)			:(opdone)
g.mti.1
	op('ldi_',getarg(i1))		:(opdone)
.fi
.if G
	ident(i.text(i1),'(xs)+')		:f(g.mti.1)
	op('pop',reg.w0)
	op('mov',reg.w0,reg.ia)			:(opdone)
g.mti.1
	op('mov',getarg(i1),reg.ia)		:(opdone)
.fi


g.mfi
*  last arg is optional
*  compare with cfp$m, branching if result negative
	eq(i.type(i2))				:s(g.mfi.1)
*  here if label given, branch if wc not in range (ie, negative)
.if A
	op('sti_',reg.w0)
.fi
.if G
	op('mov',reg.ia,reg.w0)
.fi
	op('or',reg.w0,reg.w0)
	op('js',getarg(i2))
g.mfi.1
	ident(i.text(i1),'-(xs)')		:s(g.mfi.2)
.if A
	op('sti_',getarg(i1))		:(opdone)
.fi
.if G
	op('mov',reg.ia,getarg(i1))		:(opdone)
.fi
g.mfi.2
.if A
	op('sti_',reg.w0)
.fi
.if G
	op('mov',reg.ia,reg.w0)
.fi
	op('push',reg.w0)			:(opdone)
.fi
.if A
g.ctw
*  assume cfp_c chars per word
	t1 = getarg(i1)
	eq(cfp_b,cfp_c)				:s(g.ctw.1)
*  here if one word per character, so just add character count
	op('add',t1,i.text(i2))
						:(opdone)
g.ctw.1
	op('add',t1,'(cfp_c-1)+cfp_c*' i.text(i2))
	op('shr',t1,'log_cfp_c')
					:(opdone)
g.ctb
	t1 = getarg(i1)
	op('add',t1,'(cfp_b-1)+cfp_b*' i.text(i2))
	op('and',t1,'-cfp_b')
						:(opdone)
g.cvm	t1 = getarg(i1)
	op('sti_',reg.w0)
	op('imul',reg.w0,'10')
	op('jo',t1)
	op('sub',reg.wb,'ch_d0')
	op('sub',reg.w0,reg.wb)
	op('ldi_',reg.w0)
	op('jo',t1)
						:(opdone)
.fi
.if G
g.ctb
g.ctw
	w.reg = getarg(i1); 
	op('mov',w.reg,'ctbw_r')
	op('mov' op_w,'$' i.text(i2), 'ctbw_v')
*	op('mov',w.reg,reg.w0)	
	op('call', incode '_')
	op('mov','ctbw_r',w.reg)
						:(opdone)

g.cvm	t1 = getarg(i1)
	op('mov',reg.ia,reg.w0)
	op('imul',reg.w0,intvt)
	op('jo',t1)
	op('sub','$ch_d0',reg.wb)
	op('sub',reg.wb,reg.w0)
	op('mov',reg.w0,reg.ia)
	op('jo',t1)
						:(opdone)
.fi
						:(opdone)
g.cvd
	op('cvd_')				:(opdone)

g.mvc
	it_suspend = 1
.if A
	t1 = genlab('mvc')
	op('rep')
	op('movs_b')
.fi
.if G
*	use word move if character size is word size
*	if charsize is word size, convert character count to byte count for word move

	t1 = genlab('mvc')
	it_suspend = 1
	op('rep', 'movsb')
.fi
	it_suspend = 0
						:(opdone)
g.mvw
.if A
	op('shr',reg.wa,'log_cfp_b')
 	op('rep','movs_w')
.fi
.if G
	gensh('shr',reg.wa,log_cfp_b)
 	genrep('rep', 'movs' (eq(ws,32) 'd','q'))
.fi
						:(opdone)
g.mwb
.if A
	op('shr',reg.wa,'log_cfp_b')
	op('std')
	op('lea',reg.xl,'a(XL-cfp_b)')
	op('lea',reg.xr,'a(XR-cfp_b)')
 	genrep('movs_w')
	op('cld')
.fi
.if G
	gensh('shr',reg.wa,log_cfp_b,)
	op('std')
	op('sub','$' cfp_b,reg.xl)
	op('sub','$' cfp_b,reg.xr)
 	genrep('movs' (eq(ws,32) 'd','q'))
	op('cld')				
.fi		
						:(opdone)

	op('std')
	op('shr',reg.wa,'log_cfp_b')
	op('rep')
	op('movs_w')
	op('ctd')
						:(opdone)

g.mcb
	op('std')
	op('dec',reg.xl)
	op('dec',reg.xr)
.if A
 	genrep('movs_b')
.fi
.if G
 	genrep('movs' (eq(ws,32) 'd','q'))
.fi
	op('cld')
						:(opdone)
	op('std')
	op('rep')
.if A
	op('movs_b')
.fi
.if G
	op('rep','movs' (eq(ws,32) 'd','q'))
.fi
	op('cld')
						:(opdone)
genrep
*	generate equivalent of rep op loop
	l1 = genlab('rep')
	l2 = genlab('rep')
	opl(l1 ':')
	op('or',reg.wa,reg.wa)
	op('jz',l2)
	op(op)
	op('dec',reg.wa)
	op('jmp',l1)
	opl(l2 ':')
						:(return)
-stitl	gendir(command,name) - generate directive.
gendir
	ident(command,'segment')		:s(gendir.segment)
.if A
	op(command,name)			
.fi
.if G
	op('.' command,name)
.fi
						:(return)
gendir.segment
.if A
	op(command, '.' name)		:(return)
.fi
.if G
	op('.' name)				:(return)
.fi
g.chk
	op('chk_')
	op('or',reg.w0,reg.w0);
	op('jne','sec06')			:(opdone)

decend
*  here at end of dic or dac to see if want label made public
	thislabel ? rtab(1) . thislabel ':'
        differ(pubtab[thislabel]) gendir('global',thislabel)
						:(opdone)

g.dac	
	t1 = i.type(i1)
        t2 = "" ;*(le(t1,2) "", le(t1,4) "d_offset_(", le(t1,6) "d_offset_(", "")
        opl(thislabel,d_word,t2 i.text(i1))
						:(decend)
g.dic
.if G
	outfile = '# g.dic ' i.text(i1)
.fi
	opl(thislabel,d_word,i.text(i1))
						:(decend)

g.drc
	gendir('align',8)
	t1 = i.text(i1)
	t1 ? fence "+" = ""
	op(asm_d_real,t1)
.fi
*  note that want to attach label to last instruction
	t.label(cstmts[cstmts.n]) = thislabel
	thislabel =				:(opdone)

g.dtc
*  change first and last chars to " (assume / used in source)
	t1 = i.text(i1)
	t1 tab(1) rtab(1) . t2
	t3 = remdr(size(t2),cfp_c)
*        t2 = "'" t2 "'"
*  append nulls to complete last word so constant length is multiple
*  of word word
	dtc_i = 1
	t4 =
g.dtc.1
	t4 = gt(dtc_i, 1) t4 ","
	t4 = t4 "'" substr(t2,dtc_i,1) "'"
	le(dtc_i = dtc_i + 1, size(t2))		:s(g.dtc.1)

        t4 = ne(t3) t4 dupl(',0',cfp_c - t3)
        opl(thislabel,asm_d_char,t4)
						:(opdone)
g.dbc
	opl(thislabel,d_word,getarg(i1))
						:(opdone)
g.equ
.if A
	opl(thislabel,'equ',i.text(i1))
.fi
.if G
	op('.set',thislabel,i.text(i1))
.fi
						:(opdone)
g.exp
	ppm_cases[thislabel] = i.text(i1)
*	gendir('extern',thislabel)
	thislabel =				:(opdone)

g.inp
	ppm_cases[thislabel] = i.text(i2)
	prc.count1 = ident(i.text(i1),'n') prc.count1 + 1
+						:(opnext)

g.inr						:(opnext)

g.ejc	op('')				:(opdone)

g.ttl	op('')
						:(opdone)

g.sec	op('')
	sectnow = sectnow + 1			:($("g.sec." sectnow))

* procedure declaration section
g.sec.1
	gendir('segment','text')
        gendir('global','sec01')
        opl('sec01:')	             	:(opdone)

* definitions section
g.sec.2
	gendir('segment','data')
	gendir('global','sec02')
        opl('sec02:')       		      	:(opdone)

* constants section
g.sec.3
	gendir('segment','data')
	gendir('global','sec03')
	opl('sec03:')
						:(opdone)

* working variables section
g.sec.4 
	gendir('global','esec03')
        opl('esec03' ':')
        gendir('segment','data')
        gendir('global','sec04')
	opl('sec04:')			:(opdone)

*  here at start of program section.  if any n type procedures,
*  put out entry-word block declaration at end of working storage
g.sec.5
*  emit code to indicate in code section
*  get direction set to up.
        gendir('global','esec04')
        opl('esec04' ':')
*        (gt(prc.count1) opl('prc$' ':','times', prc.count1 ' dd 0'))
.if A
	op('prc_: times ' prc.count1 ' dd 0')
.fi
.if G
	opl('prc_:','.fill', prc.count1,cfp_b)
.fi
        gendir('global','end_min_data')
        opl('end_min_data' ':')
        gendir('segment','text')
        gendir('global','sec05')
        opl('sec05' ':')
*  enable tracing if desired
						:(opdone)

*  stack overflow section.  output exi__n tail code
g.sec.6
        gendir('global','sec06')
        opl('sec06'  ':', 'nop')
				             :(opdone)

*  error section.  produce code to receive erb's
g.sec.7
        gendir('global','sec07')
        opl('sec07:')
	flush()
*  error section.  produce code to receive erb's

*	allow for some extra cases in case of max.err bad estimate
	n1 = max.err + 8
	opl('err_:')
.if A
	outfile = ';sec07:a:' a('m(' rcode ')') ':g:' g('rcode')
.fi
.if G
	outfile = '#sec07:a:' a('m(' rcode ')') ':g:' g('rcode')
.fi

	op('xchg',reg.wa,a('m(' rcode ')') g(rcode))
						:(opdone)


opdone	flush()					:(opnext)

*  here to emit bstmts, cstmts, astmts. attach input label and
*  comment to first instruction generated.

flush	
	eq(astmts.n) eq(bstmts.n) eq(cstmts.n)	:f(opdone1)
	ne(ab_suspend)				:s(opdone.2)
	

*  here if some statements to emit, so output single 'null' statement to get label
*  and comment field right.

	label = thislabel =
	outstmt(tstmt())			:(opdone.6)
opdone1	
	eq(bstmts.n)				:s(opdone.2)
	i = 1
opdone.1
	outstmt(bstmts[i])
	le(i = i + 1, bstmts.n)			:s(opdone.1)

opdone.2	eq(cstmts.n)			:s(opdone.4)
	i = 1
opdone.3
	outstmt(cstmts[i])
	le(i = i + 1, cstmts.n)			:s(opdone.3)

opdone.4	eq(astmts.n)			:s(opdone.6)
	i = 1
	ident(pifatal[incode])			:s(opdone.5)
*  here if post incrementing code not allowed
	error('post increment not allowed for op ' incode)
opdone.5	outstmt(astmts[i])
	le(i = i + 1, astmts.n)			:s(opdone.5)
opdone.6 astmts.n = bstmts.n = cstmts.n =	:(return)
flush_end

report
	output = lpad(num,7) tab text		:(return)


g.end
* here at end of code generation.

	endfile(1)
	endfile(2)
	endfile(3)
	report((ident(asm,'A') 'nasm', 'gas'),		'assembler')
        report(nlines,		'lines read')
        report(nstmts,		'statements processed')
        report(ntarget,		'target code lines produced')
	report(&stcount,	'spitbol statements executed')
        report(max.err,		'maximum err/erb number')
        report(prc.count1, 	'prc count')
        output  = '  ' gt(prc.count,prc.count1)
.	  'differing counts for n-procedures:'
.	  ' inp ' prc.count1 ' prc ' prc.count
        differ(nerrors) report(nerrors,'errors detected')

	errfile = '* ' max.err 'maximum err/erb number'
	errfile  = '* ' prc.count 'prc count'
.		differ(lasterror) '  the last error was in line ' lasterror

	&code   = ne(nerrors) 2001
        report(collect(), 'free words')
	report(time(),'execution time ms')
	&dump = 0
	:(end)
end