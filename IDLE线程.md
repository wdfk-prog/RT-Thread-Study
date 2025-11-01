---
title: IDLE线程
categories:
  - rt-thread
tags:
  - rt-thread
abbrlink: ce645444
date: 2025-10-03 09:44:51
---
# IDLE线程

- cleanup 会在线程退出时，被空闲线程回调一次以执行用户设置的清理现场等工作。

## defunct流程

1. rt_thread_defunct_enqueue 将退出线程和分离线程插入到defunct链表中
2. IDLE线程会在空闲时，执行defunct链表中的线程,将线程节点从链表中移除
3. 从对象容器中移除线程对象
4. 执行线程清除函数,释放线程控制块

