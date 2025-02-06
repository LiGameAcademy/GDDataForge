# addons/GDDataForge/source/thread_pool.gd
extends Node
class_name ThreadPool

signal task_completed(task_id: String, result: Variant)
signal all_tasks_completed

# 线程池配置
const MAX_THREADS := 4  # 最大线程数
const QUEUE_SIZE := 100 # 任务队列大小

# 线程状态
enum ThreadState {
	IDLE,
	BUSY
}

# 任务结构
class Task:
	## 任务ID
	var id: String
	## 任务回调
	var callable: Callable
	## 任务参数
	var args: Array
	## 任务优先级
	var priority: int
	
	func _init(p_id: String, p_callable: Callable, p_args: Array = [], p_priority: int = 0) -> void:
		id = p_id
		callable = p_callable
		args = p_args
		priority = p_priority

# 线程结构
class WorkerThread:
	var thread: Thread
	var state: ThreadState
	var current_task: Task
	
	func _init() -> void:
		thread = Thread.new()
		state = ThreadState.IDLE
		current_task = null

var _threads: Array[WorkerThread]
var _task_queue: Array[Task]
var _mutex: Mutex
var _semaphore: Semaphore
var _exit_thread := false
var _active_tasks := 0

func _init() -> void:
	_mutex = Mutex.new()
	_semaphore = Semaphore.new()
	_task_queue = []
	_threads = []
	
	# 创建工作线程
	for i in MAX_THREADS:
		var worker := WorkerThread.new()
		worker.thread.start(_thread_function.bind(worker))
		_threads.append(worker)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		shutdown()

## 添加任务到队列
func add_task(id: String, callable: Callable, args: Array = [], priority: int = 0) -> void:
	var task := Task.new(id, callable, args, priority)
	
	_mutex.lock()
	# 根据优先级插入任务
	var inserted := false
	for i in _task_queue.size():
		if _task_queue[i].priority < priority:
			_task_queue.insert(i, task)
			inserted = true
			break
	
	if not inserted:
		_task_queue.append(task)
	
	_mutex.unlock()
	_semaphore.post()

## 等待所有任务完成
func wait_all() -> void:
	while true:
		_mutex.lock()
		var all_done := _task_queue.is_empty() and _active_tasks == 0
		_mutex.unlock()
		
		if all_done:
			break
		
		await get_tree().process_frame

## 关闭线程池
func shutdown() -> void:
	_exit_thread = true
	
	# 通知所有等待的线程
	for i in _threads.size():
		_semaphore.post()
	
	# 等待所有线程结束
	for worker in _threads:
		worker.thread.wait_to_finish()
	
	_threads.clear()

## 线程函数
func _thread_function(worker: WorkerThread) -> void:
	while not _exit_thread:
		_semaphore.wait()
		
		if _exit_thread:
			break
		
		_mutex.lock()
		if _task_queue.is_empty():
			_mutex.unlock()
			continue
		
		worker.current_task = _task_queue.pop_front()
		worker.state = ThreadState.BUSY
		_active_tasks += 1
		_mutex.unlock()
		
		# 执行任务
		var result = worker.current_task.callable.callv(worker.current_task.args)
		
		# 通知主线程任务完成
		call_deferred("_on_task_completed", worker.current_task.id, result)
		
		_mutex.lock()
		worker.state = ThreadState.IDLE
		worker.current_task = null
		_active_tasks -= 1
		
		if _task_queue.is_empty() and _active_tasks == 0:
			call_deferred("_on_all_tasks_completed")
		_mutex.unlock()

## 任务完成回调
func _on_task_completed(task_id: String, result: Variant) -> void:
	task_completed.emit(task_id, result)

## 所有任务完成回调
func _on_all_tasks_completed() -> void:
	all_tasks_completed.emit()
