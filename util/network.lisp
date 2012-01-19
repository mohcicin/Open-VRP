;;; Mon Jun 20, 2011 (c) Marc Kuo
;;; Utilities for generating a distance table using a list of node coords.
;;; -----------------------------------------
;;; 1. create-network generates/initialises the <network> object (using node-coords)
;;; 2. read from dist-table with (distance i j)
(in-package :open-vrp.util)

(defun distance (i j dist-array)
  "Read from the distance-table with two indices."
  (aref dist-array i j))

(defun distance-coords (x1 y1 x2 y2)
  "Calculates pythagoras distance"
  (flet ((square (x)
	   (* x x)))
    (sqrt (+ (square (- x1 x2)) (square (- y1 y2))))))

(defun distance-coord-pair (n1 n2)
   "Calculates distance given two coord pairs. Returns NIL if both coords are the same."
   (if (eql n1 n2)
       NIL
       (distance-coords (car n1) (cdr n1)
			(car n2) (cdr n2))))
	         
(defgeneric node-distance (node1 node2)
  (:method (node1 node) "Inputs are not two nodes.")
  (:documentation "Given two node objects, calculate and return their distance (Cartesian)."))

(defmethod node-distance ((n1 node) (n2 node))
  (let ((x1 (node-xcor n1)) (y1 (node-ycor n1))
	(x2 (node-xcor n2)) (y2 (node-ycor n2)))
    (distance-coords x1 y1 x2 y2)))

(defun get-array-row (array row-index)
  "Given a 2-dimenstional array and a row-index, return the row as a list"
  (loop for row to (1- (array-dimension array 0))
       collect (aref array row-index row)))

(defun generate-dist-array (coord-list)
  "Given a list of coord pairs, generate an array of distances."
  (let* ((size (length coord-list))
	 (dist-array (eval `(make-array '(,size ,size) :initial-element nil))))
    (map0-n #'(lambda (x)
		 (map0-n #'(lambda (y)
			     (setf (aref dist-array x y)
				   (distance-coord-pair (nth x coord-list)
							(nth y coord-list))))
			 (1- size)))
	     (1- size))
     dist-array))
     
;; ----------------------------------------

;; Accessor functions
;;--------------------------
;; Thu Nov 10, 2011

(defgeneric node (obj id)
  (:method (obj id) "This node method only accepts a <network> or <problem> object.")
  (:documentation "Returns <Node> object, given a <network>/<problem> and a node ID (int)."))

(defmethod node ((net network) id) 
  (nth id (network-nodes net)))

(defmethod node ((prob problem) id)
  (node (problem-network prob) id))

;; --------------------------------

;; Initializing functions
;; ------------------

(defmacro create-nodes (node-coords &optional demands time-windows durations)
  (let ((nodes (gensym))
	(i (gensym))
	(coords-list (gensym))
	(demand-list (gensym))
	(tw-list (gensym))
	(dur-list (gensym)))
    `(let ((,nodes nil))
       (do ((,i 0 (1+ ,i))
	    (,coords-list ,node-coords (cdr ,coords-list))
	    ,@(when demands `((,demand-list ,demands (cdr ,demand-list))))
	    ,@(when time-windows `((,tw-list ,time-windows (cdr ,tw-list))))
	    ,@(when durations `((,dur-list ,durations (cdr ,dur-list)))))
	   ((null (car ,coords-list)))
	 (push (make-instance ,(cond (time-windows ''node-tw)
				     (demands ''node-c)
				     (t ''node))
			      :id ,i
			      :xcor (caar ,coords-list)
			      :ycor (cdar ,coords-list)
			      ,@(when demands `(:demand (car ,demand-list)))
			      ,@(when time-windows `(:start (caar ,tw-list)
						     :end (cdar ,tw-list)))
			      ,@(when durations `(:duration (car ,dur-list))))
	       ,nodes))
       (nreverse ,nodes))))
    
(defmacro create-network (node-coords &optional node-demands node-time-windows node-durations)
  "Given a coord-list, return an instance of class 'network, with nodes and dist-table initialised. Dist-table is a precalculated Cartesian distance matrix, for quick table-lookup. The nodes are created and numbered starting from 0, which is the base node. By default creates normal nodes. When node-demands are provided, it creates node-C (nodes with demand). With time-windows and durations, creates node-TW."
  `(let ((nodes (create-nodes ,node-coords
			      ,@(when node-demands `(,node-demands))
			      ,@(when node-time-windows `(,node-time-windows ,node-durations))))
	 (dist-table (generate-dist-array ,node-coords)))
     (make-instance 'network :dist-table dist-table :nodes nodes)))