do
    local etk = etk
    local Input  = etk.Widgets.Input
    local Label  = etk.Widgets.Label
    local Button = etk.Widgets.Button

    local myView = etk.View()
    
    local sanjot = Label {
        position = Position { bottom="10px", right="5px" },
        text = "Made by Sanjit (Who else has the time?)"
        
    }


    local name = Input {
            position = Position { top="10px", left="10px" },
            value = "Name?"
        }
    
    local crush = Input {
            position = Position { top="35px", left="10px" },
            value = "Crush?"
        }
        
    local check = Button {
            position = Position { top="70px", left="10px" },
            text = "Check"
        }
    
    local chance = Label {
            position = Position { top="100px", left="10px" },
            text = "0%"
        }
    
    check.onAction = function ()
        chance.text = math.floor(math.random()*100) .. "%"
    end
    
    
    myView:addChildren(name,crush,check,chance,sanjot)

    etk.RootScreen:pushScreen(myView)
end