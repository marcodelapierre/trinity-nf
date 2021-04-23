--- orig.PbsProExecutor.groovy	2021-03-19 17:59:39.000000000 +1100
+++ PbsProExecutor.groovy	2021-03-19 19:29:14.000000000 +1100
@@ -54,16 +54,12 @@
             result << '-q'  << (String)task.config.queue
         }
 
-        def res = []
-        if( task.config.hasCpus() || task.config.memory ) {
-            res << "ncpus=${task.config.getCpus()}".toString()
+        if( task.config.cpus > 1 ) {
+            result << "-l" << "ncpus=${task.config.getCpus()}".toString()
         }
         if( task.config.memory ) {
             // https://www.osc.edu/documentation/knowledge_base/out_of_memory_oom_or_excessive_memory_usage
-            res << "mem=${task.config.getMemory().getMega()}mb".toString()
-        }
-        if( res ) {
-            result << '-l' << "select=1:${res.join(':')}".toString()
+            result << "-l" << "mem=${task.config.getMemory().getMega()}mb".toString()
         }
 
         // max task duration
