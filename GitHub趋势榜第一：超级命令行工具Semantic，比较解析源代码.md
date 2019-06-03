## GitHub趋势榜第一：超级命令行工具Semantic，比较解析源代码

[新智元](javascript:void(0);) *昨天*

![img](https://mmbiz.qpic.cn/mmbiz_png/UicQ7HgWiaUb1831goQUTHsenTreiaUJrlMLGQssvDzFHvMJbPYep4ShAkXheHibOBKDW9gI39bibcgJ8tVIEqHzn2g/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

###    **新智元报道**  

来源：GitHub

编辑：大明

##### **【新智元导读】**作为开发者，天天都要与源代码打交道，面对不同版本，不同语言的代码进行比较、分析，理顺开发流程往往是开发者的日常。近日，一款名为Semantic的源代码分析比较工具一举登上了GitHub趋势榜榜首，一起来看看！



作为开发者，你是否对不同源代码段之间的解析和比较困惑不已呢？今天的GitHub趋势热榜上排名第一的帖子介绍了一款多语言支持的“超级命令行工具”Semantic，或许可以解决这个令人头疼的问题。



Semantic是一个Haskell库，也是一个用于分析和比较源代码的命令行工具。

 

本文将从**应用功能、语言支持、开发、技术和架构、许可**等五个方面介绍Semantic这款工具。



用途及功能：源代码解析、比较、图应用





**解析（Parse）**



```
Usage: semantic parse ([--sexpression] | [--json] | [--json-graph] | [--symbols]
                      | [--dot] | [--show] | [--quiet]) [FILES...]
  Generate parse trees for path(s)

Available options:
  --sexpression            Output s-expression parse trees (default)
  --json                   Output JSON parse trees
  --json-graph             Output JSON adjacency list
  --symbols                Output JSON symbol list
  --dot                    Output DOT graph parse trees
  --show                   Output using the Show instance (debug only, format
                           subject to change without notice)
  --quiet                  Don't produce output, but show timing stats
```



**比较（Diff）**



```
Usage: semantic diff ([--sexpression] | [--json] | [--json-graph] | [--toc] |
                     [--dot] | [--show]) [FILE_A] [FILE_B]
  Compute changes between paths

Available options:
  --sexpression            Output s-expression diff tree (default)
  --json                   Output JSON diff trees
  --json-graph             Output JSON diff trees
  --toc                    Output JSON table of contents diff summary
  --dot                    Output the diff as a DOT graph
  --show                   Output using the Show instance (debug only, format
                           subject to change without notice)
```

 

**图（Graph）**



```
Usage: semantic graph ([--imports] | [--calls]) [--packages] ([--dot] | [--json]
                      | [--show]) ([--root DIR] [--exclude-dir DIR]
                      DIR:LANGUAGE | FILE | --language ARG (FILES... | --stdin))
  Compute a graph for a directory or from a top-level entry point module

Available options:
  --imports                Compute an import graph (default)
  --calls                  Compute a call graph
  --packages               Include a vertex for the package, with edges from it
                           to each module
  --dot                    Output in DOT graph format (default)
  --json                   Output JSON graph
  --show                   Output using the Show instance (debug only, format
                           subject to change without notice)
  --root DIR               Root directory of project. Optional, defaults to
                           entry file/directory.
  --exclude-dir DIR        Exclude a directory (e.g. vendor)
  --language ARG           The language for the analysis.
  --stdin                  Read a list of newline-separated paths to analyze
                           from stdin. 
```



多语言支持：Python、Go，Java均可使用





![img](https://mmbiz.qpic.cn/mmbiz_png/UicQ7HgWiaUb1831goQUTHsenTreiaUJrlMSOHdyQSZTJyVpJlapk4dwGmYBEFCeZbQuhbjicpBqnbLHBzqYRBH9dQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)

 

开发环境及版本要求





我们使用cabal的Nix风格的本地版本进行开发。要快速入门，可以按照下图中的步骤：

 

- 
- 
- 
- 
- 
- 
- 

```
git clone git@github.com:github/semantic.gitcd semanticgit submodule sync --recursive && git submodule update --init --recursive --forcecabal new-updatecabal new-buildcabal new-testcabal new-run semantic -- --help
```



Semantic最低要求GHC 8.6.4。我们建议使用ghcup沙箱GHC版本。我们使用的版本基于StackageLTS版。目前的LTS版本是13.13。如果您愿意，也可以使用堆栈版。



技术和架构特征



从架构上看，Semantic具备以下特点：

 

- 可以读取blob。
- 可以为树形保护程序的blob生成解析树（用于编程工具的增量解析系统）。
- 将这些树分配为语法的通用表示。
- 执行分析，计算差异，或仅返回解析树。
- 以多种支持格式呈现输出。

 

Semantic利用了许多有趣的算法和技术：

 

- Myers算法（SES）如论文An O（ND）差分算法及其变化所述
- RWS-Diff：在分层数据中灵活高效的变化检测中描述的RWS。
- 可以单独打开Union和数据类型。
- 简要定义解释器（Abstracting Definitional Interpreters）的实现。可扩展为基于语法术语的单点表示。



关于授权许可





Semantic基于MIT许可。



参考链接：

https://github.com/github/semantic



**新智元春季招聘开启，****一起弄潮AI之巅！**

**岗位详情请戳：**

[![解决AI技术落地难题，“解耦”是关键 (3).png](https://mmbiz.qpic.cn/mmbiz_png/UicQ7HgWiaUb2M4h9tkuarGklADG9cjGMsf8bicLRzt5cibWevRjGhqg5Nr6MNwCbbSmV2WE1PdyLqytGrKJms8R0w/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1&wx_co=1)](http://mp.weixin.qq.com/s?__biz=MzI3MTA0MTk1MA==&mid=2652040487&idx=5&sn=4d39d27bf481f4651c17aa58f8e08436&chksm=f12199d6c65610c006f6640fccf6c28ace29138a132b8f6b60daa53329894dd006aaa751ea15&scene=21#wechat_redirect)



**【加入社群】**



新智元AI技术+产业社群招募中，欢迎对AI技术+产业落地感兴趣的同学，加小助手微信号：aiera2015_2   入群;通过审核后我们将邀请进群，加入社群后务必修改群备注（姓名 - 公司 - 职位;专业群审核较严，敬请谅解）。

![img](https://mmbiz.qpic.cn/mmbiz_gif/UicQ7HgWiaUb1KTwONTiaO3FZYUSGxl8ibiaHPViaYfsE4hOOOHrmyQ7r5CwkByn6oHdGmwBA6Q1I6r4eCn9gVhJQ3nA/640?wx_fmt=gif&tp=webp&wxfrom=5&wx_lazy=1)









微信扫一扫
关注该公众号