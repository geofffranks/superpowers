#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$ROOT/skills/subagent-driven-development/scripts/review-package"
VALIDATOR="$ROOT/skills/subagent-driven-development/scripts/review-package-validator"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cd "$tmp"; git init -q; git config user.email a@b; git config user.name t
echo one > a; git add a; git commit -qm one; base=$(git rev-parse HEAD)
printf 'one\ntwo\n' > a; printf 'new\n' > z; git add -A; git commit -qm two; head=$(git rev-parse HEAD)
"$SCRIPT" "$base" "$head" out --mode initial-task > stdout
[[ -f out/index.md && -f out/manifest.json ]] && grep -q 'package:' stdout && grep -q 'total_bytes:' stdout
grep -q '^# Review package index$' out/index.md
python3 - out/manifest.json out/index.md <<'PY'
import json,sys
m=json.load(open(sys.argv[1])); assert m['counts']['changes']==2
assert [c['ordinal'] for c in m['changes']]==list(range(len(m['changes'])))
assert all(h['id'] for c in m['changes'] for h in c['hunks'])
index=open(sys.argv[2]).read()
assert all(c['shard'] in index and all(h['id'] in index for h in c['hunks']) for c in m['changes'])
PY
cp -a out old; SDD_REVIEW_INJECT_PUBLICATION_FAILURE=1 "$SCRIPT" "$base" "$head" out --mode initial-task >/dev/null 2>/dev/null || test $? -eq 7
cmp out/index.md old/index.md; cmp out/manifest.json old/manifest.json
rm out/index.md
! "$VALIDATOR" out >/dev/null 2>&1
rm -rf out; cp -a old out
sed -i 's/^\\- change 0:/- incomplete change 0:/' out/index.md
! "$VALIDATOR" out >/dev/null 2>&1
python3 - "$VALIDATOR" <<'PY'
import json,os,subprocess,sys,tempfile
v=sys.argv[1]; d=tempfile.mkdtemp(); os.mkdir(d+'/shards')
json.dump({'version':1,'mode':'initial-task','ancestral':True,'base_sha':'0'*40,'head_sha':'1'*40,'limits':{'max_shard_bytes':10,'max_total_bytes':10},'commits':[],'changes':[],'counts':{'raw':0,'name_status':0,'changes':0,'shards':0,'hunks':0},'total_bytes':0},open(d+'/manifest.json','w'))
assert subprocess.run([v,d]).returncode != 0
PY
# Independent adversarial fixtures: nested commit schema, symlink shard rejection, binary metadata, newline path, limits, and incremental exits.
python3 - "$VALIDATOR" <<'PY'
import json,os,subprocess,sys,tempfile
v=sys.argv[1]; d=tempfile.mkdtemp(); os.mkdir(d+'/shards'); open(d+'/shards/x','wb').write(b'x')
m={'version':1,'mode':'initial-task','ancestral':True,'base_sha':'0'*40,'head_sha':'1'*40,'previous_review':None,'reviewed_head':None,'limits':{'max_shard_bytes':10,'max_total_bytes':10,'elevated_reason':None,'elevated_ceiling_source':None},'commits':[{'sha':'0'*40,'author':1,'email':'e','subject':'s'}],'changes':[],'counts':{'raw':0,'name_status':0,'changes':0,'shards':0,'hunks':0},'total_bytes':0}
json.dump(m,open(d+'/manifest.json','w')); assert subprocess.run([v,d],capture_output=True).returncode==6
os.unlink(d+'/shards/x'); os.symlink('/etc/passwd',d+'/shards/x'); m['commits']=[]; json.dump(m,open(d+'/manifest.json','w')); assert subprocess.run([v,d],capture_output=True).returncode==6
PY
# Real newline and binary fixtures.
git config core.quotePath false; printf 'binary\0data' > bin; git add bin; git commit -qm binary; b2=$(git rev-parse HEAD); printf 'changed\0data' > bin; printf 'newline\npath\n' > $'line\nname'; git add -A; git commit -qm edges; h2=$(git rev-parse HEAD); "$SCRIPT" "$b2" "$h2" edge-out --mode initial-task >/dev/null; python3 - edge-out/manifest.json <<'PY'
import json,sys
m=json.load(open(sys.argv[1])); assert any(c['classification']=='binary' for c in m['changes']); assert any('line' in c['path']['value'] for c in m['changes'])
PY
# Canonical raw-byte identity: UTF-8 and equivalent base64 spellings must not duplicate.
python3 - "$VALIDATOR" edge-out <<'PY'
import base64,json,os,shutil,subprocess,sys,tempfile
v,source=sys.argv[1:]
def package(name):
    d=os.path.join(tempfile.mkdtemp(),name); shutil.copytree(source,d); return d
def manifest(d):
    with open(d+'/manifest.json') as f: return json.load(f)
def save(d,m):
    with open(d+'/manifest.json','w') as f: json.dump(m,f)
def check(d,expected):
    assert (subprocess.run([v,d]).returncode == 0) is expected
# Bytes/checksum mutation has exactly one defect.
d=package('checksum'); m=manifest(d)
with open(d+'/'+m['changes'][0]['shard'],'r+b') as f:
    original=f.read(1)
    f.seek(0)
    f.write(bytes([original[0] ^ 1]))
check(d,False)
# Invalid base64 mutation has exactly one defect.
d=package('invalid-base64'); m=manifest(d)
m['changes'][0]['path'].update(encoding='base64',value='%%%='); save(d,m); check(d,False)
# An unlisted extra shard is rejected, then removal restores validity.
d=package('removed-extra'); open(d+'/shards/extra.bin','wb').close(); check(d,False); os.remove(d+'/shards/extra.bin'); check(d,True)
# Adding an unlisted extra shard is rejected.
d=package('added-extra'); open(d+'/shards/extra.bin','wb').write(b'extra'); check(d,False)
# Duplicate canonical path mutation has exactly one defect.
d=package('duplicate'); m=manifest(d); c=m['changes'][0]; clone=dict(c)
clone['id']='f'*64; clone['ordinal']=1; clone['path']={'encoding':'base64','value':base64.b64encode(c['path']['value'].encode()).decode()}
clone['shard']='shards/duplicate.bin'; shutil.copy(d+'/'+c['shard'],d+'/'+clone['shard'])
m['changes']=[c,clone]; m['counts'].update(raw=2,name_status=2,changes=2,shards=2); m['total_bytes']*=2
save(d,m); check(d,False)
# File and hunk identities are recomputed from the Git range, not trusted.
d=package('identity-tamper'); m=manifest(d); c=m['changes'][0]; c['id']='f'*64; save(d,m); check(d,False)
d=package('hunk-identity-tamper'); m=manifest(d); c=next(c for c in m['changes'] if c['hunks']); c['hunks'][0]['id']='e'*64; save(d,m); check(d,False)
PY
printf 'S2 focused cases passed\n'
