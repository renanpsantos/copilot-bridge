// Verify the actual import graph without starting any server or loading user secrets.
try {
 for(const name of ['express','@modelcontextprotocol/sdk/client/index.js','@modelcontextprotocol/sdk/client/stdio.js','@modelcontextprotocol/sdk/server/index.js','@modelcontextprotocol/sdk/server/streamableHttp.js','@modelcontextprotocol/sdk/types.js'])await import(name);
 console.log('Dependencias do adaptador: OK');
}catch(error){
 console.log(String(error?.message||error));
 process.exitCode=1;
}
