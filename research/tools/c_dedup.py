import re,collections,sys
s=open(sys.argv[1]).read()
funcs=re.findall(r'^static [^\n]*?(gg_function_\d+)\(([^\n]*)\) \{\n(.*?)^\}\n', s, re.S|re.M)
local=re.compile(r'\b(?:[ptvl]|label|gg_frame_)\d+\b')
def body(params,b):
    m={}
    def r(x):
        k=x.group(0); m.setdefault(k,'L%d'%len(m)); return m[k]
    return local.sub(r, params+'|'+b)
bodies={n:body(p,b) for n,p,b in funcs}
size={n:len(b) for n,p,b in funcs}
cls={n:0 for n in bodies}
call=re.compile(r'gg_function_\d+')
while True:
    keys={n:call.sub(lambda x:'F%d'%cls.get(x.group(0),-1), bodies[n]) for n in bodies}
    ids={}
    new={n:ids.setdefault(keys[n],len(ids)) for n in bodies}
    if len(set(new.values()))==len(set(cls.values())): break
    cls=new
groups=collections.defaultdict(list)
for n,c in cls.items(): groups[c].append(n)
dup=sum(size[v[0]]*(len(v)-1) for v in groups.values())
print(len(bodies),'functions,',len(groups),'distinct; duplicate body bytes',dup,'of file',len(s))
print(collections.Counter(len(v) for v in groups.values()).most_common(10))
if len(sys.argv)>2:
    rep={}
    for v in groups.values():
        v=sorted(v,key=lambda x:int(x.split('_')[-1]))
        for n in v: rep[n]=v[0]
    drop={n for n in rep if rep[n]!=n}
    # remove definitions and prototypes and frame structs of dropped functions
    out=[]
    pos=0
    defre=re.compile(r'^static [^\n]*?\b(gg_function_\d+)\([^\n]*\) \{\n.*?^\}\n', re.S|re.M)
    s2=defre.sub(lambda m: '' if m.group(1) in drop else m.group(0), s)
    s2=re.sub(r'^static [^\n]*?\b(gg_function_\d+)\([^\n]*\);\n', lambda m: '' if m.group(1) in drop else m.group(0), s2, flags=re.M)
    s2=re.sub(r'\bgg_function_\d+\b', lambda m: rep.get(m.group(0), m.group(0)), s2)
    open(sys.argv[2],'w').write(s2); print('wrote',len(s2))
