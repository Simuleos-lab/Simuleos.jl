# recursively parses the AST of a piece of code and builds a knowledge
# graph of all relationships between entities
function process_expr!(kg::KnowledgeGraph, expr, parent_id::String, file_path::String, line_offset::Int=0)
    # Skip non-expressions
    if !(expr isa Expr)
        return nothing
    end

    # Get line number if available
    line_num = if hasfield(typeof(expr), :line)
        expr.line + line_offset
    else
        0
    end
    
    # Process based on expression head
    if expr.head == :function
        # Function definition: first arg is signature, second is body
        func_name = if expr.args[1] isa Symbol
            String(expr.args[1])
        elseif expr.args[1].head == :call
            String(expr.args[1].args[1])
        else
            "anonymous"
        end
        
        # Create function node
        func_id = add_node!(kg, KGNode(
            next_id("func"),
            :Function,
            func_name,
            Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
            string(expr.args[1]),
            nothing
        ))
        
        # Add relation from parent to this function
        add_relation!(kg, parent_id, :defines, func_id)
        
        # Process function signature for parameters
        if expr.args[1] isa Expr && expr.args[1].head == :call
            for i in 2:length(expr.args[1].args)
                param = expr.args[1].args[i]
                
                # Handle typed params (x::Type)
                param_name = if param isa Symbol
                    String(param)
                elseif param isa Expr && param.head == :(::)
                    String(param.args[1])
                else
                    "param_$i"
                end
                
                param_type = if param isa Expr && param.head == :(::)
                    string(param.args[2])
                else
                    nothing
                end
                
                # Create parameter node
                param_id = add_node!(kg, KGNode(
                    next_id("param"),
                    :Parameter,
                    param_name,
                    Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
                    nothing,
                    param_type
                ))
                
                # Link parameter to function
                add_relation!(kg, func_id, :has_param, param_id)
            end
        end
        
        # Process function body
        process_expr!(kg, expr.args[2], func_id, file_path, line_num)
        
    elseif expr.head == :(->)
        # Lambda function: first arg is parameters, second is body
        # Create function node
        func_id = add_node!(kg, KGNode(
            next_id("lambda"),
            :Function,
            "anonymous",
            Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
            string(expr),
            nothing
        ))
        
        # Add relation from parent
        add_relation!(kg, parent_id, :defines, func_id)
        
        # Process parameters
        if expr.args[1] isa Symbol
            # Single parameter
            param_name = String(expr.args[1])
            param_id = add_node!(kg, KGNode(
                next_id("param"),
                :Parameter,
                param_name,
                Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
                nothing,
                nothing
            ))
            add_relation!(kg, func_id, :has_param, param_id)
        elseif expr.args[1] isa Expr && expr.args[1].head == :tuple
            # Multiple parameters
            for (i, param) in enumerate(expr.args[1].args)
                param_name = if param isa Symbol
                    String(param)
                else
                    "param_$i"
                end
                
                param_id = add_node!(kg, KGNode(
                    next_id("param"),
                    :Parameter,
                    param_name,
                    Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
                    nothing,
                    nothing
                ))
                add_relation!(kg, func_id, :has_param, param_id)
            end
        end
        
        # Process body
        process_expr!(kg, expr.args[2], func_id, file_path, line_num)
        
    elseif expr.head == :call
        # Function call
        call_id = add_node!(kg, KGNode(
            next_id("call"),
            :CallSite,
            nothing,
            Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
            string(expr),
            nothing
        ))
        
        # Add relation from parent
        add_relation!(kg, parent_id, :contains, call_id)
        
        # If the callee is a symbol, create a reference node
        if expr.args[1] isa Symbol
            func_ref_id = add_node!(kg, KGNode(
                next_id("ref"),
                :Reference,
                String(expr.args[1]),
                Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
                nothing,
                nothing
            ))
            add_relation!(kg, call_id, :calls, func_ref_id)
        else
            # If not a symbol, process the callee expression
            callee_id = process_expr!(kg, expr.args[1], call_id, file_path, line_num)
            if callee_id !== nothing
                add_relation!(kg, call_id, :calls, callee_id)
            end
        end
        
        # Process arguments
        for i in 2:length(expr.args)
            arg_id = process_expr!(kg, expr.args[i], call_id, file_path, line_num)
        end
        
        return call_id
        
    elseif expr.head == :return
        # Return statement
        ret_id = add_node!(kg, KGNode(
            next_id("ret"),
            :Return,
            nothing,
            Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
            string(expr),
            nothing
        ))
        
        # Add relation from parent
        add_relation!(kg, parent_id, :contains, ret_id)
        
        # Process the returned expression
        if length(expr.args) > 0
            expr_id = process_expr!(kg, expr.args[1], ret_id, file_path, line_num)
            if expr_id !== nothing
                add_relation!(kg, ret_id, :returns, expr_id)
            end
        end
        
    elseif expr.head == :(=)
        # Assignment
        assign_id = add_node!(kg, KGNode(
            next_id("assign"),
            :Assignment,
            nothing,
            Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
            string(expr),
            nothing
        ))
        
        # Add relation from parent
        add_relation!(kg, parent_id, :contains, assign_id)
        
        # Create variable node
        if expr.args[1] isa Symbol
            var_name = String(expr.args[1])
            var_id = add_node!(kg, KGNode(
                next_id("var"),
                :Variable,
                var_name,
                Dict(:file => file_path, :start_line => line_num, :end_line => line_num),
                nothing,
                nothing
            ))
            
            # Link assignment to variable
            add_relation!(kg, assign_id, :assigns, var_id)
        end
        
        # Process the right-hand side
        rhs_id = process_expr!(kg, expr.args[2], assign_id, file_path, line_num)
        
    elseif expr.head == :block
        # Code block - process each statement
        for stmt in expr.args
            if stmt isa LineNumberNode
                line_num = stmt.line + line_offset
            else
                process_expr!(kg, stmt, parent_id, file_path, line_num)
            end
        end
    end
    
    return nothing
end